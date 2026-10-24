"""Sequential GPU experiment queue. Failed/incomplete jobs never count as completed runs."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def run(wait_for, root):
    while True:
        try:
            record = json.loads(wait_for.read_text(encoding='utf-8'))
        except (OSError, json.JSONDecodeError):
            time.sleep(5)
            continue
        if record['status'] == 'completed':
            break
        if record['status'] == 'failed':
            raise RuntimeError(f'Preceding experiment failed: {record.get("failure")}')
        time.sleep(5)
    candidates = [
        ('nano-512', ['--variant', 'nano', '--size', '512', '--batch', '4', '--accumulate', '2', '--lr', '.0003', '--encoder-lr', '.00015']),
        ('seg-nano-384', ['--variant', 'seg-nano', '--size', '384', '--batch', '4', '--accumulate', '2']),
    ]
    environment = dict(os.environ, PYTHONIOENCODING='utf-8', NO_ALBUMENTATIONS_UPDATE='1')
    for name, arguments in candidates:
        output = root/name
        existing = output/'experiment.json'
        if existing.exists():
            if json.loads(existing.read_text(encoding='utf-8'))['status'] == 'completed':
                continue
            raise ValueError(f'Existing incomplete experiment: {output}; inspect before retrying')
        log = root.parent.parent/'target'/f'transfer-{name}.log'
        log.parent.mkdir(parents=True, exist_ok=True)
        print(json.dumps({'starting': name, 'output': str(output), 'log': str(log)}), flush=True)
        with log.open('w', encoding='utf-8') as stream:
            subprocess.run([sys.executable, '-m', 'ml.transfer_train', '--output', str(output), '--epochs', '30', '--workers', '0', *arguments],
                           stdout=stream, stderr=subprocess.STDOUT, check=True, env=environment)
        print(json.dumps({'completed': name}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wait-for', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=Path('training-runs/transfer-comparison'))
    args = parser.parse_args()
    run(args.wait_for, args.root)
