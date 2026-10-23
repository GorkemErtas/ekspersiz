"""Offline audit of reviewed local checkpoints and available dataset metadata.

Run from ai-service: python scripts/audit_production_models.py
No training, inference, downloads or checkpoint modifications are performed.
Only hash-verified, trusted local PyTorch checkpoints are deserialized.
"""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import torch
import yaml
from app.model_contract import ARTIFACT_SHA256, DAMAGE_CLASSES, PART_CLASSES, verify_artifact, verify_names


def audit():
    artifacts = {
        'vehicle': (ROOT / 'yolo11n.pt', None, None),
        'damage': (ROOT / 'models/candidates/damage_detection_v2_cardd_5class.pt',
                   DAMAGE_CLASSES, ROOT / 'datasets/vehicle_damage_detection_v2/data.yaml'),
        'part': (ROOT / 'models/vehicle_part_best.pt', PART_CLASSES,
                 ROOT / 'datasets/vehicle_part/data.yaml'),
    }
    report = {}
    for role, (path, expected, dataset) in artifacts.items():
        verify_artifact(path, role)
        checkpoint = torch.load(path, map_location='cpu', weights_only=False)
        names = checkpoint['model'].names
        if expected is not None:
            verify_names(names, expected)
        args = checkpoint.get('train_args', {})
        item = {
            'path': str(path.relative_to(ROOT)), 'sha256': ARTIFACT_SHA256[role],
            'classes': names, 'checkpoint_date': checkpoint.get('date'),
            'ultralytics_version': checkpoint.get('version'),
            'training_args': {key: args.get(key) for key in
                              ('data', 'model', 'epochs', 'imgsz', 'seed', 'deterministic', 'task')},
            'dataset_names_match': None,
        }
        if dataset is not None and dataset.is_file():
            metadata = yaml.safe_load(dataset.read_text(encoding='utf-8'))
            verify_names(metadata['names'], expected)
            item['dataset_names_match'] = True
            item['label_files_by_split'] = {
                split: len(list((dataset.parent / 'labels' / folder).rglob('*.txt')))
                for split, folder in [('train', 'train'), ('val', 'valid' if role == 'part' else 'val'), ('test', 'test')]
            }
        report[role] = item
    print(json.dumps(report, indent=2, ensure_ascii=True))


if __name__ == '__main__':
    audit()
