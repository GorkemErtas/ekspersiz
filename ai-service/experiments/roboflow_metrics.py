"""Eleven-class evaluation without production aliases or inflated absent-class AP."""
import math


def metric_report(metrics, names: list[str], support: dict[str, int]) -> dict:
    def finite(value):
        result = float(value)
        return result if math.isfinite(result) else None

    keys = ('precision', 'recall', 'map50', 'map50_95')
    box = metrics.box
    positions = {int(class_id): index for index, class_id in enumerate(box.ap_class_index)}
    classes = {}
    for class_id, name in enumerate(names):
        position = positions.get(class_id)
        values = box.class_result(position) if position is not None and support[name] else [None]*4
        status = ('undefined_no_ground_truth' if not support[name] else
                  'measured' if position is not None else 'not_reported_by_evaluator')
        classes[name] = {'class_id': class_id, 'instances': support[name],
                         'status': status,
                         **{key: finite(v) if v is not None else None for key, v in zip(keys, values)}}
    matrix = metrics.confusion_matrix.matrix
    return {
        'aggregate': dict(zip(keys, map(finite, box.mean_results()))),
        'per_class': classes,
        'focus_classes': {name: classes.get(name, {'status': 'NOT_PRESENT_IN_SOURCE_TAXONOMY', 'map50_95': None})
                          for name in ('BROKEN_PART', 'BROKEN_LAMP', 'BROKEN_MIRROR', 'BROKEN_GLASS', 'CRACKED_GLASS')},
        'confusion_matrix': {'labels': names + ['background'], 'rows': 'predicted', 'columns': 'ground_truth',
                             'values': matrix.tolist()},
        'interpretation': 'P/R uses max-F1 confidence; AP integrates PR curves. No-GT class AP is null, not aggregate mAP.',
    }
