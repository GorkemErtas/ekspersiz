"""Independent complete-holdout ONNX accuracy parity; never enable an unapproved bundle."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from app.vision.processing import quality

from .metrics import score
from .transfer_benchmark import load_candidate


def verify(bundle, data, reference, output):
    backend, manifest = load_candidate(bundle)
    document = json.loads(data.read_text(encoding='utf-8'))
    expected = json.loads(reference.read_text(encoding='utf-8'))
    if expected['split_sha256'] != hashlib.sha256(data.read_bytes()).hexdigest() or expected['checkpoint_sha256'] != manifest['damage_checkpoint_sha256']:
        raise ValueError('Parity reference split/checkpoint mismatch')
    if expected['preprocessing'] != manifest['damage_preprocessing']:
        raise ValueError('Parity reference preprocessing mismatch')
    root = Path(document['info']['source_root'])
    predictions = {'damage': [], 'part': []}
    quality_rejected = []
    for row in document['images']:
        with Image.open(root/row['file_name']) as source:
            image = source.convert('RGB')
        if not quality(image)['suitable']:
            quality_rejected.append(row['id'])
        # Low threshold for AP; operating-point metrics separately use the chosen threshold.
        damage, parts = backend.detect(image, threshold=.001, part_threshold=.001)
        for task, detections in (('damage', damage), ('part', parts)):
            if task not in row['tasks']:
                continue
            for detection in detections:
                box = detection['boundingBox']
                predictions[task].append({'image_id': row['id'], 'category_id': detection['classId'], 'score': detection['confidence'],
                                          'bbox': [box['x1'], box['y1'], box['x2']-box['x1'], box['y2']-box['y1']]})
    damage_metrics = score(document, 'damage', predictions['damage'])
    delta = {key: abs(damage_metrics[key]-expected['damage'][key]) for key in ('mAP50_95', 'mAP50', 'precision', 'recall')}
    quantized = bool(manifest.get('quantization'))
    drops = {key: expected['damage'][key]-damage_metrics[key] for key in delta}
    rare_recall_drops = {name: metrics['recall']-damage_metrics['per_class'][name]['recall'] for name,metrics in expected['damage']['per_class'].items()}
    acceptable = (all(drops[key] <= .005 for key in ('mAP50_95','mAP50'))
                  and all(drops[key] <= .02 for key in ('precision','recall'))
                  and all(drop <= .05 for drop in rare_recall_drops.values())) if quantized else all(v < 1e-4 for v in delta.values())
    report = {'bundle': str(bundle), 'split_sha256': expected['split_sha256'], 'damage': damage_metrics,
              'damage_difference_from_torch': delta,
              'operating_point': score(document, 'damage', predictions['damage'], manifest['threshold']),
              'api_quality_rejected_image_ids': quality_rejected,
              'api_quality_gated_operating_point': score(document, 'damage', [p for p in predictions['damage'] if p['image_id'] not in quality_rejected], manifest['threshold']),
              'part': score(document, 'part', predictions['part']),
              'accuracy_parity_passed': None if quantized else acceptable,
              'quantization_accuracy_check_passed': acceptable if quantized else None,
              'quantization_metric_drops': drops if quantized else None,
              'quantization_per_class_recall_drops': rare_recall_drops if quantized else None,
              'production_approved': False}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    if not acceptable:
        raise ValueError('ONNX accuracy differs beyond the declared tolerance; candidate rejected')
    print(json.dumps(report), flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--data', type=Path, required=True)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    verify(args.bundle, args.data, args.reference, args.output)
