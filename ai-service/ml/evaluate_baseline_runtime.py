"""Measure the existing unified ONNX bundle with the common evaluator, without activation."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

from app.vision.processing import preprocess, postprocess
from .metrics import score


def evaluate(bundle, data, output):
    import onnxruntime as ort
    manifest = json.loads((bundle/'manifest.json').read_text(encoding='utf-8'))
    catalog = json.loads((bundle/'classes.json').read_text(encoding='utf-8'))
    for filename, key in (('model.onnx', 'model_sha256'), ('classes.json', 'catalog_sha256')):
        if hashlib.sha256((bundle/filename).read_bytes()).hexdigest() != manifest[key]:
            raise ValueError('Historical bundle checksum mismatch')
    categories = {task: sorted((c for c in catalog['categories'] if c['task'] == task), key=lambda c: c['task_index'])
                  for task in ('damage', 'part')}
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(bundle/'model.onnx'), sess_options=options, providers=['CPUExecutionProvider'])
    document = json.loads(data.read_text(encoding='utf-8'))
    root = Path(document['info']['source_root'])
    predictions = {'damage': [], 'part': []}
    for row in document['images']:
        with Image.open(root/row['file_name']) as source:
            image = source.convert('RGB')
        tensor, ratio = preprocess(image, manifest['input_size'])
        outputs = session.run(['damage', 'part'], {'images': tensor[None]})
        for task, raw in zip(('damage', 'part'), outputs):
            if task not in row['tasks']:
                continue
            for detection in postprocess(raw, categories[task], ratio, image.width, image.height,
                                         threshold=.001, nms=manifest['nms_threshold']):
                box = detection['boundingBox']
                predictions[task].append({'image_id': row['id'], 'category_id': detection['classId'],
                                          'score': detection['confidence'],
                                          'bbox': [box['x1'], box['y1'], box['x2']-box['x1'], box['y2']-box['y1']]})
    report = {'bundle': str(bundle), 'model_sha256': manifest['model_sha256'],
              'split_sha256': hashlib.sha256(data.read_bytes()).hexdigest(),
              'nms_threshold': manifest['nms_threshold'],
              'damage': score(document, 'damage', predictions['damage'], manifest['threshold']),
              'part': score(document, 'part', predictions['part'], manifest['threshold']),
              'predictions': predictions, 'production_approved': False}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({task: {k:report[task][k] for k in ('mAP50_95','mAP50','precision','recall','false_positive')}
                      for task in ('damage','part')}), flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, default=Path('models/hitl-416'))
    parser.add_argument('--data', type=Path, default=Path('datasets/hitl-coco/test.json'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    evaluate(args.bundle, args.data, args.output)
