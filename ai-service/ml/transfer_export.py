"""Export a candidate RF-DETR damage / YOLOX part ensemble, never production-approved."""
import argparse
import hashlib
from importlib.metadata import distribution
import json
import os
from pathlib import Path
import shutil

import numpy as np
from PIL import Image
import torch
from torch import nn

from app.vision.rfdetr_processing import preprocess_rfdetr
from app.vision.processing import preprocess
from .model import load_checkpoint


class DamageGraph(nn.Module):
    def __init__(self, network):
        super().__init__()
        self.network = network

    def forward(self, images):
        outputs = self.network(images)
        return outputs[:2]


class PartGraph(nn.Module):
    def __init__(self, model):
        super().__init__()
        self.backbone = model.backbone
        self.head = model.heads['part']

    def forward(self, images):
        return self.head(self.backbone(images))


def export(checkpoint, part_checkpoint, output, image_paths, threshold=.25, experiment=None, antialias=True):
    os.environ['NO_ALBUMENTATIONS_UPDATE'] = '1'
    from rfdetr import RFDETR
    import onnxruntime as ort
    os.environ.setdefault('HF_HUB_OFFLINE', '1')
    torch.set_num_threads(2)
    if not .25 <= threshold <= 1:
        raise ValueError('Threshold must respect the existing API confidence floor of 0.25')
    from .transfer_train import WEIGHTS
    experiment = experiment or checkpoint.parent/'experiment.json'
    provenance = json.loads(experiment.read_text(encoding='utf-8'))
    pretrained = provenance['pretrained']
    if (provenance['variant'] not in WEIGHTS or pretrained['license'] != 'Apache-2.0'
            or (pretrained['filename'], pretrained['md5']) != WEIGHTS[provenance['variant']]
            or not pretrained['url'].startswith('https://storage.googleapis.com/rfdetr/')):
        raise ValueError('Unreviewed pretrained-weight provenance')
    if output.exists():
        raise ValueError('Use a new bundle path; existing candidates are immutable')
    output.mkdir(parents=True)
    model = RFDETR.from_checkpoint(str(checkpoint), device='cpu')
    size = model.model_config.resolution
    network = model.model.model.cpu().eval()
    images = []
    for path in image_paths:
        with Image.open(path) as image:
            images.append(image.convert('RGB'))
    inputs = [torch.from_numpy(preprocess_rfdetr(im, size, antialias)[None]) for im in images]
    with torch.inference_mode():
        original = [network(x) for x in inputs]
    network.export()
    damage = DamageGraph(network).eval()
    parts, metadata = load_checkpoint(part_checkpoint)
    parts = PartGraph(parts.eval()).eval()
    graphs = [('damage', damage, inputs[0], ['boxes', 'logits']),
              ('part', parts, torch.from_numpy(preprocess(images[0], 416)[0][None]), ['part'])]
    for name, graph, example, names in graphs:
        torch.onnx.export(graph, example, str(output/f'{name}.onnx'), input_names=['images'],
                          output_names=names, opset_version=17, dynamo=False)
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    damage_session = ort.InferenceSession(str(output/'damage.onnx'), sess_options=options, providers=['CPUExecutionProvider'])
    part_session = ort.InferenceSession(str(output/'part.onnx'), sess_options=options, providers=['CPUExecutionProvider'])
    parity = []
    for im, tensor, reference in zip(images, inputs, original):
        observed = damage_session.run(None, {'images': tensor.numpy()})
        errors = []
        raw_allclose = True
        for actual, expected in zip(observed, (reference['pred_boxes'].numpy(), reference['pred_logits'].numpy())):
            raw_allclose = raw_allclose and bool(np.allclose(actual, expected, atol=3e-4, rtol=3e-4))
            errors.append(float(np.max(np.abs(actual-expected))))
        # DETR predicts sets. Encoder TopK boundaries can change low-score rows while
        # preserving decoded detections. Check the actual API set as well; never hide
        # a failed raw-array comparison or replace complete-holdout accuracy checks.
        from app.vision.rfdetr_processing import postprocess_rfdetr
        from .metrics import overlap
        from scipy.optimize import linear_sum_assignment
        canonical = json.loads((Path(__file__).resolve().parents[1]/'app/vision/classes.json').read_text(encoding='utf-8'))
        categories = sorted((c for c in canonical['categories'] if c['task'] == 'damage'), key=lambda c: c['task_index'])
        expected_set = postprocess_rfdetr(reference['pred_boxes'].numpy(), reference['pred_logits'].numpy(), categories, im.width, im.height)
        actual_set = postprocess_rfdetr(*observed, categories, im.width, im.height)
        if len(expected_set) != len(actual_set):
            raise ValueError('Decoded API detection count changed during export')
        def bbox(item):
            b = item['boundingBox']
            return [b['x1'], b['y1'], b['x2']-b['x1'], b['y2']-b['y1']]
        costs = np.array([[1-overlap(bbox(a), bbox(b))+int(a['classId'] != b['classId']) for b in actual_set] for a in expected_set])
        pairs = linear_sum_assignment(costs) if expected_set else ([], [])
        min_iou, max_score_error = 1., 0.
        for i, j in zip(*pairs):
            a, b = expected_set[i], actual_set[j]
            if a['classId'] != b['classId']:
                raise ValueError('Decoded API class changed during export')
            min_iou = min(min_iou, overlap(bbox(a), bbox(b)))
            max_score_error = max(max_score_error, abs(a['confidence']-b['confidence']))
        if min_iou < .999 or max_score_error > .001:
            raise ValueError('Decoded API detection set changed beyond export tolerance')
        part_input = torch.from_numpy(preprocess(im, 416)[0][None])
        with torch.inference_mode():
            expected_part = parts(part_input).numpy()
        actual_part = part_session.run(None, {'images': part_input.numpy()})[0]
        np.testing.assert_allclose(actual_part, expected_part, atol=2e-3, rtol=1e-3)
        parity.append({'image_size': list(im.size), 'damage_max_absolute_errors': errors,
                       'damage_raw_array_allclose': raw_allclose,
                       'damage_api_set_parity_passed': True, 'matched_min_iou': min_iou,
                       'matched_max_score_error': max_score_error,
                       'part_max_absolute_error': float(np.max(np.abs(actual_part-expected_part)))})
    catalog_path = Path(__file__).resolve().parents[1]/'app/vision/classes.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    if metadata['catalog'] != catalog:
        raise ValueError('Historical part model catalog mismatch')
    shutil.copyfile(catalog_path, output/'classes.json')
    (output/'training_provenance.json').write_text(json.dumps(provenance, indent=2)+'\n', encoding='utf-8')
    licenses = output/'licenses'
    licenses.mkdir()
    shutil.copyfile(Path(__file__).parent/'vendor/yolox/LICENSE', licenses/'YOLOX-LICENSE')
    shutil.copyfile(Path(__file__).parent/'vendor/yolox/NOTICE.md', licenses/'YOLOX-NOTICE.md')
    for path in distribution('rfdetr').files or []:
        if path.name == 'LICENSE':
            shutil.copyfile(distribution('rfdetr').locate_file(path), licenses/'RF-DETR-LICENSE')
            break
    if not (licenses/'RF-DETR-LICENSE').exists():
        raise ValueError('Missing RF-DETR license text')
    (licenses/'NOTICE.md').write_text('RF-DETR: Copyright Roboflow, Apache-2.0. COCO-pretrained Nano model fine-tuned on HITL CC0.\n'
        'YOLOX: Copyright Megvii, Apache-2.0; local part model trained from scratch on HITL CC0.\n'
        'EksperSiz modifications: task-specific fine-tuning, part-only export, ensemble adapter.\n'
        'Experimental bundle; production approval is false.\n', encoding='utf-8')
    manifest = {'format': 'ensemble-v1', 'schema_version': 'hitl-v1', 'production_approved': False,
                'model_version': f'hitl-rfdetr-{size}-'+hashlib.sha256(checkpoint.read_bytes()).hexdigest()[:12],
                'input_sizes': {'damage': size, 'part': 416}, 'outputs': ['boxes', 'logits', 'part'],
                'damage_preprocessing': 'RGB-square-PIL-bilinear-ImageNet-v1' if antialias else 'RGB-square-bilinear-no-antialias-ImageNet-v1',
                'part_preprocessing': 'BGR-letterbox-114-v1', 'threshold': threshold, 'part_threshold': .25,
                'nms_threshold': .45, 'num_select': model.model_config.num_select,
                'num_queries': model.model_config.num_queries,
                'damage_checkpoint_sha256': hashlib.sha256(checkpoint.read_bytes()).hexdigest(),
                'part_checkpoint_sha256': hashlib.sha256(part_checkpoint.read_bytes()).hexdigest(),
                'training_provenance_sha256': hashlib.sha256((output/'training_provenance.json').read_bytes()).hexdigest(),
                'catalog_sha256': hashlib.sha256((output/'classes.json').read_bytes()).hexdigest(),
                'damage_sha256': hashlib.sha256((output/'damage.onnx').read_bytes()).hexdigest(),
                'part_sha256': hashlib.sha256((output/'part.onnx').read_bytes()).hexdigest(),
                'requires_complete_holdout_accuracy_check': True,
                'parity': parity}
    (output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(manifest), flush=True)
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkpoint', type=Path, required=True)
    parser.add_argument('--part-checkpoint', type=Path, default=Path('training-runs/hitl-tiny-416/best.pth'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--images', nargs='+', type=Path, required=True)
    parser.add_argument('--threshold', type=float, default=.25)
    parser.add_argument('--experiment', type=Path, help='Required when exporting a checkpoint snapshot outside its run directory')
    parser.add_argument('--antialias', action=argparse.BooleanOptionalAction, default=True)
    args = parser.parse_args()
    export(args.checkpoint, args.part_checkpoint, args.output, args.images, args.threshold, args.experiment, args.antialias)
