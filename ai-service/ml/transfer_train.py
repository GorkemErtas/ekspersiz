"""Fine-tune only explicitly Apache-designated RF-DETR models on frozen HITL views."""
import argparse
import hashlib
from importlib.metadata import version
import json
import os
from pathlib import Path
import sys
import time

APP_ROOT = Path(__file__).resolve().parents[1]
WEIGHTS = {
    'nano': ('rf-detr-nano.pth', 'fb6504cce7fbdc783f7a46991f07639f'),
    'seg-nano': ('rf-detr-seg-nano.pt', '9995497791d0ff1664a1d9ddee9cfd20'),
}


def train(args):
    os.environ['NO_ALBUMENTATIONS_UPDATE'] = '1'
    os.environ['PYTHONIOENCODING'] = 'utf-8'
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, 'reconfigure'):
            stream.reconfigure(encoding='utf-8')
    if version('rfdetr') != '1.11.2':
        raise ValueError('Use the reviewed rfdetr==1.11.2 training environment')
    os.environ.setdefault('RF_HOME', str(APP_ROOT/'models/pretrained-rfdetr'))
    os.environ.setdefault('HF_HOME', str(APP_ROOT/'target/huggingface'))
    os.environ.setdefault('TORCH_HOME', str(APP_ROOT/'target/torch-cache'))
    os.environ.setdefault('HF_HUB_OFFLINE', '1')
    import torch
    from pytorch_lightning import seed_everything
    from rfdetr import RFDETRNano, RFDETRSegNano
    from rfdetr.assets.model_weights import ModelWeights, download_pretrain_weights
    if not torch.cuda.is_available():
        raise RuntimeError('This experiment requires a CUDA GPU; no training is fabricated')
    torch.set_num_threads(4)
    seed_everything(args.seed, workers=True)
    provenance = json.loads((args.data/'provenance.json').read_text(encoding='utf-8'))
    if provenance.get('test_exposed_to_training') is not False or (args.data/'test').exists():
        raise ValueError('The training view must not contain the frozen test set')
    if args.output.exists() and not args.resume:
        raise ValueError('Use a new run directory or explicit --resume')
    filename, expected_md5 = WEIGHTS[args.variant]
    asset = ModelWeights.from_filename(filename)
    if asset is None or asset.md5_hash != expected_md5 or not asset.url.startswith('https://storage.googleapis.com/rfdetr/'):
        raise ValueError('Unreviewed pretrained asset')
    # Download only this allowlisted publisher asset, never a mirror or Plus model.
    weights = Path(os.environ['RF_HOME'])/filename
    weights.parent.mkdir(parents=True, exist_ok=True)
    download_pretrain_weights(str(weights))
    if hashlib.md5(weights.read_bytes()).hexdigest() != expected_md5:
        raise ValueError('Publisher pretrained checksum mismatch')
    cls = RFDETRNano if args.variant == 'nano' else RFDETRSegNano
    model = cls(pretrain_weights=str(weights), resolution=args.size, num_classes=len(provenance['original_to_task_id']),
                device='cuda', gradient_checkpointing=True)
    if model.model_config.license != 'Apache-2.0':
        raise ValueError('Only Apache-designated models are allowed')
    config = dict(dataset_dir=str(args.data.resolve()), output_dir=str(args.output.resolve()),
                  epochs=args.epochs, batch_size=args.batch, grad_accum_steps=args.accumulate,
                  eval_batch_size=1 if args.variant == 'seg-nano' else args.batch,
                  lr=args.lr, lr_encoder=args.encoder_lr, weight_decay=1e-4,
                  warmup_epochs=1., lr_scheduler='cosine', num_workers=args.workers,
                  multi_scale=False, expanded_scales=False, scale_jitter=args.crop_augmentation or args.variant == 'seg-nano',
                  augmentation_backend='albumentations',
                  aug_config={'HorizontalFlip': {'p': .5}, 'ColorJitter': {'brightness': .15, 'contrast': .15, 'saturation': .1, 'hue': .02, 'p': .5}},
                  amp_dtype='bf16', use_ema=True, eval_backend='faster_coco_eval',
                  run_test=False, tensorboard=False, wandb=False, mlflow=False, clearml=False,
                  progress_bar=None, eval_interval=1, checkpoint_interval=5,
                  early_stopping=True, early_stopping_patience=10, seed=args.seed,
                  notes={'purpose': 'HITL transfer experiment, no production approval', 'data': provenance})
    if args.resume:
        config['resume'] = str(args.resume.resolve())
    args.output.mkdir(parents=True, exist_ok=True)
    record = {'variant': args.variant, 'input_size': args.size, 'rfdetr': version('rfdetr'),
              'torch': torch.__version__, 'gpu': torch.cuda.get_device_name(),
              'training_packages': {name:version(name) for name in ('albumentations','opencv-python-headless','pytorch-lightning','transformers','numpy')},
              'pretrained': {'filename': filename, 'url': asset.url, 'license': 'Apache-2.0',
                             'md5': expected_md5, 'sha256': hashlib.sha256(weights.read_bytes()).hexdigest()},
              'model_config': model.model_config.model_dump(), 'training_config': config,
              'production_approved': False, 'status': 'started'}
    record_path = args.output/'experiment.json'
    record_path.write_text(json.dumps(record, indent=2, default=str)+'\n', encoding='utf-8')
    started = time.perf_counter()
    try:
        model.train(**config)
    except Exception as exc:
        record.update(status='failed', failure=repr(exc), elapsed_seconds=time.perf_counter()-started)
        record_path.write_text(json.dumps(record, indent=2, default=str)+'\n', encoding='utf-8')
        raise
    record.update(status='completed', elapsed_seconds=time.perf_counter()-started,
                  cuda_peak_mib=torch.cuda.max_memory_allocated()/1024**2)
    record_path.write_text(json.dumps(record, indent=2, default=str)+'\n', encoding='utf-8')
    print(json.dumps({'status': 'completed', 'output': str(args.output), 'seconds': record['elapsed_seconds']}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=Path('datasets/transfer-damage-balanced'))
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--variant', choices=tuple(WEIGHTS), default='nano')
    parser.add_argument('--size', type=int, default=384)
    parser.add_argument('--epochs', type=int, default=30)
    parser.add_argument('--batch', type=int, default=2)
    parser.add_argument('--accumulate', type=int, default=4)
    parser.add_argument('--lr', type=float, default=1e-4)
    parser.add_argument('--encoder-lr', type=float, default=5e-5)
    parser.add_argument('--workers', type=int, default=2)
    parser.add_argument('--seed', type=int, default=2026)
    parser.add_argument('--resume', type=Path)
    parser.add_argument('--crop-augmentation', action='store_true', help='Enable the framework bbox/mask-aware crop branch on training only; enabled for the segmentation candidate')
    train(parser.parse_args())
