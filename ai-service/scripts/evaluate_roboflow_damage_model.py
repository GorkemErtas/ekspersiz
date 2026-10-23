"""Evaluate only a reviewed RF eleven-class detection checkpoint; no cross-taxonomy mAP."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from experiments.config import safe_name, select_device
from experiments.roboflow_dataset import mapping, sha256, validate_experiment, write_json
from experiments.roboflow_metrics import metric_report
from scripts.train_roboflow_damage_model import environment


def evaluate(args):
    data = args.data.resolve()
    review = (args.review or data.parent/'review.json').resolve()
    validate_experiment(data, review=review)
    if not args.weights.is_file():
        raise ValueError('Checkpoint must exist locally.')
    if not 0 < args.conf < 1 or not 0 < args.iou <= 1:
        raise ValueError('Invalid evaluation thresholds.')
    report = json.loads((data.parent/'import-report.json').read_text(encoding='utf-8'))
    run = ROOT/'evaluation-runs/roboflow-v3'/safe_name(args.name)
    if run.exists():
        raise ValueError('Evaluation name already exists.')
    from ultralytics import YOLO
    model = YOLO(str(args.weights.resolve()), task='detect')
    names = mapping()['model_names']
    if model.task != 'detect' or model.names != dict(enumerate(names)):
        raise ValueError('Exact RF class names/IDs required. CarDD mAP is not directly comparable.')
    run.mkdir(parents=True)
    settings = dict(data=str(data), split=args.split, imgsz=args.imgsz, batch=args.batch,
                    conf=args.conf, iou=args.iou, max_det=300, device=select_device(args.device),
                    workers=0, plots=True, save_json=False, project=str(run.parent), name=run.name, exist_ok=True)
    provenance = {'checkpoint_sha256': sha256(args.weights), 'dataset_report_sha256': sha256(data.parent/'import-report.json'),
                  'evaluator_sha256': sha256(Path(__file__)),
                  'review_sha256': sha256(review), 'environment': environment(), 'settings': settings,
                  'started_at': datetime.now(timezone.utc).isoformat(), 'state': 'evaluating'}
    write_json(run/'evaluation.json', provenance)
    try:
        metrics = model.val(**settings)
        provenance['metrics'] = metric_report(metrics, names, report['class_counts'][args.split])
        provenance['state'] = 'completed'
    except BaseException as error:
        provenance.update(state='failed_or_interrupted', error=f'{type(error).__name__}: {error}')
        raise
    finally:
        provenance['finished_at'] = datetime.now(timezone.utc).isoformat()
        write_json(run/'evaluation.json', provenance)


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data', type=Path, default=ROOT/'datasets/vehicle_damage_detection_v3_rf/data.yaml')
    p.add_argument('--review', type=Path)
    p.add_argument('--weights', type=Path, required=True)
    p.add_argument('--name', required=True)
    p.add_argument('--split', choices=('val', 'test'), default='test')
    p.add_argument('--imgsz', type=int, default=640)
    p.add_argument('--batch', type=int, default=8)
    p.add_argument('--conf', type=float, default=.001)
    p.add_argument('--iou', type=float, default=.60)
    p.add_argument('--device', default='0')
    return p


if __name__ == '__main__':
    evaluate(parser().parse_args())
