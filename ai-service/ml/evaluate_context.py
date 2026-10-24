"""Validation-only ablation: does observed part evidence reduce off-vehicle false positives?"""
import argparse
import hashlib
import json
from pathlib import Path

import onnxruntime as ort
from PIL import Image

from app.vision.processing import preprocess, postprocess
from .metrics import score


def contains_fraction(damage, part):
    x, y, w, h = damage
    px, py, pw, ph = part
    return max(0., min(x+w, px+pw)-max(x, px))*max(0., min(y+h, py+ph)-max(y, py))/max(w*h, 1e-12)


def evaluate(data, predictions, bundle, output):
    if data.stem != 'val':
        raise ValueError('Context decisions use validation only')
    document = json.loads(data.read_text(encoding='utf-8'))
    reference = json.loads(predictions.read_text(encoding='utf-8'))
    manifest = json.loads((bundle/'manifest.json').read_text(encoding='utf-8'))
    if hashlib.sha256((bundle/'part.onnx').read_bytes()).hexdigest() != manifest['part_sha256']:
        raise ValueError('Part graph checksum mismatch')
    catalog = json.loads((bundle/'classes.json').read_text(encoding='utf-8'))
    categories = sorted((c for c in catalog['categories'] if c['task'] == 'part'), key=lambda c: c['task_index'])
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(bundle/'part.onnx'), sess_options=options, providers=['CPUExecutionProvider'])
    evidence = {}
    root = Path(document['info']['source_root'])
    for row in document['images']:
        if 'damage' not in row['tasks']:
            continue
        with Image.open(root/row['file_name']) as image:
            image = image.convert('RGB')
        pixels, ratio = preprocess(image, 416)
        detections = postprocess(session.run(['part'], {'images': pixels[None]})[0], categories, ratio, image.width, image.height, .4, .5)
        evidence[row['id']] = []
        for part in detections:
            b = part['boundingBox']
            evidence[row['id']].append([b['x1'], b['y1'], b['x2']-b['x1'], b['y2']-b['y1']])
    sweep = {}
    for minimum in (0., .1, .25, .5):
        retained = [p for p in reference['predictions'] if minimum == 0 or any(
            contains_fraction(p['bbox'], part) >= minimum for part in evidence[p['image_id']])]
        sweep[str(minimum)] = score(document, 'damage', retained)
    report = {'source': str(predictions), 'split': 'val', 'part_model_sha256': manifest['part_sha256'],
              'part_confidence_floor': .4, 'minimum_damage_box_containment_sweep': sweep,
              'note': 'Unannotated part images are inferred, not treated as missing part detections. This does not validate the semantic damage-to-part relationship.'}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:{n:v[n] for n in ('mAP50_95', 'precision', 'recall', 'false_positive')} for k,v in sweep.items()}))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=Path('datasets/hitl-coco/val.json'))
    parser.add_argument('--predictions', type=Path, required=True)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    evaluate(args.data, args.predictions, args.bundle, args.output)
