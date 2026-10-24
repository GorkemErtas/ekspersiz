"""Validation-only decoder ablations and localization/classification error diagnostics."""
import argparse
from collections import defaultdict
import json
from pathlib import Path

from .metrics import score, overlap


def diagnose(data, predictions, output):
    if data.stem != 'val':
        raise ValueError('Use validation only for decoder/hyperparameter decisions')
    document = json.loads(data.read_text(encoding='utf-8'))
    reference = json.loads(predictions.read_text(encoding='utf-8'))
    groups = defaultdict(list)
    for prediction in reference['predictions']:
        groups[prediction['image_id'], prediction['category_id']].append(prediction)
    sweep = {}
    for threshold in (.3, .5, .7, 1.):
        retained = []
        for group in groups.values():
            kept = []
            for prediction in sorted(group, key=lambda p: p['score'], reverse=True):
                if not any(overlap(prediction['bbox'], k['bbox']) > threshold for k in kept):
                    kept.append(prediction)
            retained.extend(kept)
        metrics = score(document, 'damage', retained)
        sweep[str(threshold)] = {k:v for k,v in metrics.items() if k != 'per_class'}
    cats = [c for c in document['categories'] if c['task'] == 'damage']
    indices = {c['id']: i for i,c in enumerate(cats)}
    truth, detected = defaultdict(list), defaultdict(list)
    for annotation in document['annotations']:
        if annotation['category_id'] in indices:
            truth[annotation['image_id']].append(annotation)
    for prediction in reference['predictions']:
        if prediction['score'] >= .25:
            detected[prediction['image_id']].append(prediction)
    confusion = [[0]*(len(cats)+1) for _ in range(len(cats)+1)]
    localized = total = 0
    for image_id, annotations in truth.items():
        total += len(annotations)
        used = set()
        for prediction in sorted(detected[image_id], key=lambda p: p['score'], reverse=True):
            best, j = max(((overlap(prediction['bbox'], ann['bbox']), j) for j,ann in enumerate(annotations) if j not in used), default=(0, -1))
            if best >= .5:
                used.add(j)
                localized += 1
                confusion[indices[annotations[j]['category_id']]][indices[prediction['category_id']]] += 1
            else:
                confusion[-1][indices[prediction['category_id']]] += 1
        for j, ann in enumerate(annotations):
            if j not in used:
                confusion[indices[ann['category_id']]][-1] += 1
    report = {'source': str(predictions), 'split': 'val', 'nms_sweep': sweep,
              'class_agnostic_localization_recall_at_025': localized/max(total, 1),
              'class_aware_operating_point': score(document, 'damage', reference['predictions']),
              'confusion_class_names': [c['name'] for c in cats]+['background'], 'confusion_matrix': confusion,
              'note': 'Class-agnostic localization is diagnostic only; it does not count a wrong damage class as a correct API prediction.'}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'output': str(output), 'localization_recall': report['class_agnostic_localization_recall_at_025']}))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=Path('datasets/hitl-coco/val.json'))
    parser.add_argument('--predictions', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    diagnose(args.data, args.predictions, args.output)
