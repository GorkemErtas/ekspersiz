"""Diagnose DETR set/encoder-TopK sensitivity separately from graph conversion errors."""
import argparse
import json
import os
from pathlib import Path

import numpy as np
from PIL import Image
import torch

from app.vision.rfdetr_processing import preprocess_rfdetr, postprocess_rfdetr
from .metrics import overlap


def diagnose(checkpoint, graph, photos, output):
    os.environ['NO_ALBUMENTATIONS_UPDATE'] = '1'
    from rfdetr import RFDETR
    import onnxruntime as ort
    from scipy.optimize import linear_sum_assignment
    torch.set_num_threads(2)
    model = RFDETR.from_checkpoint(str(checkpoint), device='cpu')
    network = model.model.model.eval()
    catalog = json.loads((Path(__file__).resolve().parents[1]/'app/vision/classes.json').read_text(encoding='utf-8'))
    cats = sorted((c for c in catalog['categories'] if c['task'] == 'damage'), key=lambda c: c['task_index'])
    inputs, references = [], []
    with torch.inference_mode():
        for path in photos:
            with Image.open(path) as source:
                image = source.convert('RGB')
            tensor = torch.from_numpy(preprocess_rfdetr(image, model.model_config.resolution, True)[None])
            result = network(tensor)
            inputs.append((image, tensor))
            references.append([result['pred_boxes'].numpy(), result['pred_logits'].numpy()])
        network.export()
        options = ort.SessionOptions()
        options.intra_op_num_threads = 2
        options.inter_op_num_threads = 1
        session = ort.InferenceSession(str(graph), sess_options=options, providers=['CPUExecutionProvider'])
        reports = []
        for (image, tensor), reference in zip(inputs, references):
            exported = [t.numpy() for t in network(tensor)[:2]]
            actual = session.run(None, {'images': tensor.numpy()})
            a = postprocess_rfdetr(*reference, cats, image.width, image.height)
            b = postprocess_rfdetr(*actual, cats, image.width, image.height)
            def bbox(item):
                q = item['boundingBox']
                return [q['x1'], q['y1'], q['x2']-q['x1'], q['y2']-q['y1']]
            cost = np.array([[1-overlap(bbox(x), bbox(y))+int(x['classId'] != y['classId']) for y in b] for x in a])
            pairs = linear_sum_assignment(cost) if a and b else ([], [])
            reports.append({'image_size': list(image.size),
                            'original_vs_exported_torch_max_abs': [float(np.max(np.abs(x-y))) for x,y in zip(reference, exported)],
                            'exported_torch_vs_ort_max_abs': [float(np.max(np.abs(x-y))) for x,y in zip(exported, actual)],
                            'api_detection_counts': [len(a), len(b)],
                            'matched_min_iou': min((overlap(bbox(a[i]), bbox(b[j])) for i,j in zip(*pairs)), default=None),
                            'matched_max_score_error': max((abs(a[i]['confidence']-b[j]['confidence']) for i,j in zip(*pairs)), default=None),
                            'matched_class_mismatches': sum(a[i]['classId'] != b[j]['classId'] for i,j in zip(*pairs))})
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(reports, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(reports), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkpoint', type=Path, required=True)
    parser.add_argument('--graph', type=Path, required=True)
    parser.add_argument('--photos', type=Path, nargs='+', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    diagnose(args.checkpoint, args.graph, args.photos, args.output)
