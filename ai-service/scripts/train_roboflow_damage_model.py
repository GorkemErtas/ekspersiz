"""Review-gated YOLO11n/s detection experiment, separate from production training."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from experiments.config import safe_name, select_device
from experiments.roboflow_dataset import MAPPING, mapping, sha256, validate_experiment, write_json


def environment() -> dict:
    versions = {}
    for name in ('ultralytics', 'torch', 'torchvision', 'numpy', 'Pillow', 'opencv-python-headless', 'PyYAML'):
        try:
            versions[name] = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            versions[name] = None
    result = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True, check=False)
    changes = subprocess.run(['git', 'status', '--porcelain'], cwd=ROOT, capture_output=True, text=True, check=False)
    return {'python': sys.version, 'platform': platform.platform(), 'packages': versions,
            'git_commit': result.stdout.strip(), 'git_dirty': bool(changes.stdout.strip()),
            'runner_sha256': sha256(Path(__file__)), 'contract_sha256': sha256(ROOT/'experiments/roboflow_dataset.py')}


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data', type=Path, default=ROOT/'datasets/vehicle_damage_detection_v3_rf/data.yaml')
    p.add_argument('--review', type=Path)
    p.add_argument('--variant', choices=('n', 's'), default='n')
    p.add_argument('--weights', type=Path, help='Explicit existing, trusted local YOLO11 detection checkpoint; no download.')
    p.add_argument('--name', default='rf11-n-seed42')
    p.add_argument('--epochs', type=int, default=100)
    p.add_argument('--patience', type=int, default=20)
    p.add_argument('--batch', type=int, default=8)
    p.add_argument('--imgsz', type=int, default=640)
    p.add_argument('--seed', type=int, default=42)
    p.add_argument('--workers', type=int, default=0)
    p.add_argument('--device', default='0')
    p.add_argument('--check-only', action='store_true', help='Validate data and review; never loads a model or starts training.')
    return p


def train(args):
    data = args.data.resolve()
    review = (args.review or data.parent/'review.json').resolve()
    validation = validate_experiment(data, review=review)
    if args.check_only:
        print(json.dumps({'ready': True, 'validation': validation}, indent=2))
        return
    if not args.weights or not args.weights.is_file():
        raise ValueError('An existing local --weights checkpoint is required; no automatic downloads.')
    if min(args.epochs, args.batch, args.imgsz, args.patience) <= 0 or args.workers < 0:
        raise ValueError('Training parameters must be positive (workers may be zero).')
    run = ROOT/'training-runs/roboflow-v3'/safe_name(args.name)
    if run.exists():
        raise ValueError('Run exists. Choose a new name; never overwrite experiments.')
    # Validate before creating any run or importing Ultralytics/CUDA.
    run.mkdir(parents=True)
    provenance = {'started_at': datetime.now(timezone.utc).isoformat(), 'state': 'prepared',
                  'environment': environment(), 'settings': {k: str(v) if isinstance(v, Path) else v for k,v in vars(args).items()},
                  'dataset_report_sha256': sha256(data.parent/'import-report.json'),
                  'review_sha256': sha256(review), 'mapping_sha256': sha256(MAPPING),
                  'initial_checkpoint_sha256': sha256(args.weights), 'validation': validation,
                  'selection_policy': 'best validation mAP50-95; test set is not used for selection'}
    write_json(run/'experiment.json', provenance)
    os.environ.setdefault('CUBLAS_WORKSPACE_CONFIG', ':4096:8')
    try:
        from ultralytics import YOLO
        import torch
        model = YOLO(str(args.weights.resolve()), task='detect')
        architecture = model.model.yaml
        if model.task != 'detect' or architecture.get('scale') != args.variant or 'yolo11' not in str(architecture.get('yaml_file', '')).lower():
            raise ValueError('Checkpoint must match the requested YOLO11n/s detection architecture.')
        if len(model.names) != 80:
            raise ValueError('Baseline requires a COCO-pretrained checkpoint; do not mix CarDD class heads.')
        device = select_device(args.device)
        provenance['cuda'] = {'available': torch.cuda.is_available(), 'runtime': torch.version.cuda,
                              'cudnn': torch.backends.cudnn.version(),
                              'device_name': torch.cuda.get_device_name(device) if isinstance(device, int) and torch.cuda.is_available() else str(device)}
        provenance['state'] = 'training'
        write_json(run/'experiment.json', provenance)
        model.train(data=str(data), epochs=args.epochs, patience=args.patience, batch=args.batch,
                    imgsz=args.imgsz, seed=args.seed, deterministic=True, device=device, workers=args.workers,
                    project=str(run.parent), name=run.name, exist_ok=True, pretrained=True, cls_remap=False,
                    save=True, save_period=10, cache=False, plots=True, val=True, resume=False)
        # Ultralytics writes args.yaml, results.csv (train losses + val metrics), curves, best/last.pt.
        provenance['state'] = 'completed'
        provenance['outputs'] = {p.relative_to(run).as_posix(): sha256(p) for p in sorted(run.rglob('*'))
                                 if p.is_file() and p.name != 'experiment.json'}
    except BaseException as error:
        provenance['state'] = 'failed_or_interrupted'
        provenance['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        provenance['finished_at'] = datetime.now(timezone.utc).isoformat()
        write_json(run/'experiment.json', provenance)


if __name__ == '__main__':
    train(parser().parse_args())
