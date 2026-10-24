"""Isolated comparison primitives. Never alias the two BROKEN_PART heads.

AP: confidence-ranked, class-aware greedy matching, 101 recall points, IoU
0.50:0.05:0.95. This is a documented bbox protocol, not a COCO API wrapper.
"""
from __future__ import annotations

import re
import numpy as np

COMMON = ('SCRATCH', 'DENT', 'CRACK')
NAMES = {
    'cardd': ('SCRATCH', 'DENT', 'CRACK', 'BROKEN_PART', 'BROKEN_GLASS'),
    'roboflow': ('BROKEN_PART', 'CRACK', 'DENT', 'MISSING_PART', 'PAINT_DAMAGE',
                 'SCRATCH', 'BROKEN_LAMP', 'BROKEN_MIRROR', 'CRACKED_GLASS',
                 'DENT_HAIL', 'TIRE_FLAT'),
}


def common_id(source, native_id):
    name = NAMES[source][native_id]
    return COMMON.index(name) if name in COMMON else None


def common_objects(source, objects):
    return [dict(o, cls=common_id(source, o['cls'])) for o in objects
            if common_id(source, o['cls']) is not None]


def eligible(record):
    # Drop the whole image, including damage omitted by the CarDD importer.
    return (not record.get('hidden_tire') and bool(record['gt'])
            and all(common_id(record['source'], o['cls']) is not None for o in record['gt']))


def family(stem):
    stem = re.sub(r'\.rf\.[a-f0-9]+$', '', stem.lower())
    return re.sub(r'_(jpg|jpeg|png)$', '', stem)


def iou(a, b):
    a, b = np.asarray(a), np.asarray(b)
    intersection = np.maximum(0, np.minimum(a[2:], b[2:]) - np.maximum(a[:2], b[:2])).prod()
    union = np.maximum(0, a[2:] - a[:2]).prod() + np.maximum(0, b[2:] - b[:2]).prod() - intersection
    return float(intersection / union) if union else 0.


def match(gt, pred, threshold=.5, class_aware=True):
    """Highest confidence first; each GT can be used at most once."""
    used, pairs = set(), []
    for p in sorted(range(len(pred)), key=lambda i: (-pred[i]['conf'], i)):
        candidates = [(iou(pred[p]['box'], g['box']), j) for j, g in enumerate(gt)
                      if j not in used and (not class_aware or g['cls'] == pred[p]['cls'])]
        if candidates:
            overlap, g = max(candidates, key=lambda item: (item[0], -item[1]))
            if overlap >= threshold:
                used.add(g)
                pairs.append((p, g, overlap))
    return pairs


def average_precision(flags, scores, support):
    if not support:
        return None
    if not len(flags):
        return 0.
    order = np.argsort(-np.asarray(scores), kind='stable')
    flags = np.asarray(flags, dtype=float)[order]
    tp = flags.cumsum()
    recall, precision = tp / support, tp / np.arange(1, len(tp) + 1)
    precision = np.maximum.accumulate(precision[::-1])[::-1]
    return float(np.mean([precision[recall >= r].max() if np.any(recall >= r) else 0.
                          for r in np.linspace(0, 1, 101)]))


def evaluate(items, names=COMMON, operating=.25, high_conf=.8):
    n = len(names)
    matrix = np.zeros((n + 1, n + 1), dtype=int)
    support = np.zeros(n, dtype=int)
    counts = np.zeros((n, 3), dtype=int)  # TP, FP, FN (class-aware)
    ap_flags = [[[] for _ in range(10)] for _ in names]
    scores = [[] for _ in names]
    events, high, extra = [], [], []
    for item in items:
        gt, predictions = item['gt'], item['pred']
        for g in gt:
            support[g['cls']] += 1
        for c in range(n):
            scores[c].extend(p['conf'] for p in predictions if p['cls'] == c)
        for t, threshold in enumerate(np.linspace(.5, .95, 10)):
            matched = {p for p, _, _ in match(gt, predictions, float(threshold))}
            for c in range(n):
                ap_flags[c][t].extend(i in matched for i, p in enumerate(predictions) if p['cls'] == c)
        pred = [p for p in predictions if p['conf'] >= operating]
        pairs = match(gt, pred)
        ps, gs = {p for p, _, _ in pairs}, {g for _, g, _ in pairs}
        image_events = []
        for p, prediction in enumerate(pred):
            status = 'TP' if p in ps else 'FP'
            counts[prediction['cls'], 0 if p in ps else 1] += 1
            pair = next(((g, overlap) for j, g, overlap in pairs if j == p), None)
            event = dict(image=item['id'], status=status, prediction=prediction,
                         gt_index=pair[0] if pair else None, iou=pair[1] if pair else None)
            image_events.append(event)
            if p not in ps and prediction['conf'] >= high_conf:
                high.append(event)
        for g, truth in enumerate(gt):
            if g not in gs:
                counts[truth['cls'], 2] += 1
                image_events.append(dict(image=item['id'], status='FN', gt=truth, gt_index=g))
        events.extend(image_events)
        # Diagnostic class confusion is class-agnostic geometric matching.
        # It is intentionally separate from AP/TP matching.
        cm_pairs = match(gt, pred, class_aware=False)
        cm_ps, cm_gs = {p for p, _, _ in cm_pairs}, {g for _, g, _ in cm_pairs}
        for p, g, _ in cm_pairs:
            matrix[pred[p]['cls'], gt[g]['cls']] += 1
        for p, prediction in enumerate(pred):
            if p not in cm_ps:
                matrix[prediction['cls'], n] += 1
        for g, truth in enumerate(gt):
            if g not in cm_gs:
                matrix[n, truth['cls']] += 1
        extra.extend(dict(image=item['id'], prediction=p) for p in item.get('other_pred', [])
                     if p['conf'] >= operating)
    classes = {}
    for c, name in enumerate(names):
        tp, fp, fn = map(int, counts[c])
        precision = tp / (tp + fp) if tp + fp else None
        recall = tp / (tp + fn) if tp + fn else None
        aps = [average_precision(ap_flags[c][t], scores[c], int(support[c])) for t in range(10)]
        classes[name] = dict(instances=int(support[c]), tp=tp, fp=fp, fn=fn,
                             precision=precision, recall=recall,
                             f1=2*tp/(2*tp+fp+fn) if 2*tp+fp+fn else None,
                             ap50=aps[0], ap50_95=float(np.mean(aps)) if support[c] else None,
                             ap_by_iou=aps)
    return dict(images=len(items), per_class=classes, operating_conf=operating,
                confusion_matrix=dict(labels=list(names)+['background'], rows='prediction',
                                      columns='ground_truth', values=matrix.tolist()),
                high_confidence_fp=high, other_head_alerts=extra, matches=events,
                totals=dict(tp=int(counts[:, 0].sum()), fp=int(counts[:, 1].sum()), fn=int(counts[:, 2].sum())))


def contaminated_components(records, edges):
    """Any test connected, even transitively, to train/val is excluded."""
    parent = list(range(len(records)))
    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for e in edges:
        a, b = root(e['left']), root(e['right'])
        parent[a] = b
    roots = [root(i) for i in range(len(records))]
    contaminated = {roots[i] for i, r in enumerate(records) if r['split'] != 'test'}
    return roots, {i for i, r in enumerate(records) if r['split'] == 'test' and roots[i] in contaminated}
