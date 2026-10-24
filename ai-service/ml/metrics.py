"""Common COCO and operating-point metrics for all candidate architectures."""
from collections import defaultdict
import contextlib
import io

import numpy as np


def overlap(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    inter = max(0, min(ax+aw, bx+bw)-max(ax, bx))*max(0, min(ay+ah, by+bh)-max(ay, by))
    return inter/max(aw*ah+bw*bh-inter, 1e-12)


def operating_point(annotations, predictions, categories, threshold=.25, iou_type='bbox'):
    truth, predicted = defaultdict(list), defaultdict(list)
    for ann in annotations:
        truth[ann['image_id'], ann['category_id']].append(ann)
    for pred in predictions:
        if pred['score'] >= threshold:
            predicted[pred['image_id'], pred['category_id']].append(pred)
    counts = {c['id']: {'true_positive': 0, 'false_positive': 0, 'false_negative': 0} for c in categories}
    for key in truth.keys() | predicted.keys():
        used = set()
        count = counts[key[1]]
        for pred in sorted(predicted[key], key=lambda p: p['score'], reverse=True):
            def pair_overlap(ann):
                if iou_type == 'segm':
                    from pycocotools import mask as mask_utils
                    return float(mask_utils.iou([pred['segmentation']], [ann['segmentation']], [0])[0, 0])
                return overlap(pred['bbox'], ann['bbox'])
            best, index = max(((pair_overlap(ann), i) for i, ann in enumerate(truth[key]) if i not in used), default=(0, -1))
            if best >= .5:
                used.add(index)
                count['true_positive'] += 1
            else:
                count['false_positive'] += 1
        count['false_negative'] += len(truth[key])-len(used)

    def finish(count):
        tp, fp, fn = (count[k] for k in ('true_positive', 'false_positive', 'false_negative'))
        p, r = tp/max(tp+fp, 1), tp/max(tp+fn, 1)
        return {**count, 'precision': p, 'recall': r, 'f1': 2*p*r/max(p+r, 1e-12), 'f2': 5*p*r/max(4*p+r, 1e-12)}

    totals = {k: sum(c[k] for c in counts.values()) for k in ('true_positive', 'false_positive', 'false_negative')}
    return {**finish(totals), 'threshold': threshold,
            'per_class': {c['name']: finish(counts[c['id']]) for c in categories}}


def score(document, task, predictions, threshold=.25, iou_type='bbox'):
    from pycocotools.coco import COCO
    from pycocotools.cocoeval import COCOeval
    cats = sorted((c for c in document['categories'] if c['task'] == task), key=lambda c: c['id'])
    ids = {r['id'] for r in document['images'] if task in r['tasks']}
    cat_ids = {c['id'] for c in cats}
    annotations = [a for a in document['annotations'] if a['image_id'] in ids and a['category_id'] in cat_ids]
    predictions = [p for p in predictions if p['image_id'] in ids and p['category_id'] in cat_ids]
    with contextlib.redirect_stdout(io.StringIO()):
        gt = COCO()
        gt.dataset = {'images': [r for r in document['images'] if r['id'] in ids], 'annotations': annotations, 'categories': cats, 'info': {}}
        gt.createIndex()
        if predictions:
            dt = gt.loadRes(predictions)
        else:
            dt = COCO()
            dt.dataset = {'images': gt.dataset['images'], 'annotations': [], 'categories': cats}
            dt.createIndex()
        metric = COCOeval(gt, dt, iou_type)
        metric.params.imgIds = sorted(ids)
        metric.params.catIds = sorted(cat_ids)
        metric.evaluate()
        metric.accumulate()
        metric.summarize()
    point = operating_point(annotations, predictions, cats, threshold, iou_type)
    for k, category in enumerate(cats):
        p = metric.eval['precision'][:, :, k, 0, -1]
        valid = p[p >= 0]
        point['per_class'][category['name']]['mAP50_95'] = float(valid.mean()) if len(valid) else None
        p50 = p[0][p[0] >= 0]
        point['per_class'][category['name']]['mAP50'] = float(p50.mean()) if len(p50) else None
        point['per_class'][category['name']]['annotations'] = sum(a['category_id'] == category['id'] for a in annotations)
    return {**point, 'mAP50_95': float(metric.stats[0]), 'mAP50': float(metric.stats[1]),
            'mAP_small': float(metric.stats[3]), 'mAP_medium': float(metric.stats[4]), 'mAP_large': float(metric.stats[5]),
            'average_recall_100': float(metric.stats[8]), 'images': len(ids),
            'false_positives_per_image': point['false_positive']/max(len(ids), 1),
            'iou_type': iou_type, 'negative_only_fpr': None,
            'note': 'Operating-point matching is class-aware; clean-image FPR cannot be measured without verified negative images.'}


def calibrate(document, task, predictions, minimum_precision=.7):
    cats = [c for c in document['categories'] if c['task'] == task]
    ids = {c['id'] for c in cats}
    image_ids = {r['id'] for r in document['images'] if task in r['tasks']}
    annotations = [a for a in document['annotations'] if a['category_id'] in ids and a['image_id'] in image_ids]
    predictions = [p for p in predictions if p['category_id'] in ids and p['image_id'] in image_ids]
    points = [operating_point(annotations, predictions, cats, float(t)) for t in np.arange(.25, .951, .025)]
    feasible = [p for p in points if p['precision'] >= minimum_precision and p['true_positive'] >= 10]
    best = max(feasible or points, key=lambda p: (p['f2'], p['precision']))
    return {'split': 'val', 'minimum_precision': minimum_precision, 'constraint_satisfied': bool(feasible),
            'selected': best, 'curve': [{k:v for k,v in p.items() if k != 'per_class'} for p in points]}
