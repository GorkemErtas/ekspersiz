"""Freeze validation selection, then compare trained candidates on common holdouts and CPU."""
import argparse
import gc
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

from PIL import Image

from .metrics import score, calibrate
from .signatures import split_signature


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def compact(value):
    return {k:v for k,v in value.items() if k not in ('predictions', 'calibration')}


def main(args):
    runs = {'nano-384': args.nano384, 'nano-512': args.nano512, 'seg-nano-384': args.seg}
    while True:
        states = {name:read(run/'experiment.json')['status'] for name,run in runs.items()}
        if any(status == 'failed' for status in states.values()):
            raise ValueError(f'Cannot finalize failed training: {states}')
        if all(status == 'completed' for status in states.values()):
            break
        if not args.wait:
            raise ValueError(f'Training is incomplete: {states}')
        print(json.dumps({'waiting_for_training': states}), flush=True)
        time.sleep(30)
    from .transfer_evaluate import evaluate
    from .transfer_export import export
    from .transfer_verify import verify
    from .model import load_checkpoint
    from .data import CocoTasks
    from .evaluate import evaluate as baseline_evaluate
    if args.output.exists() or args.models.exists():
        raise ValueError('Use new final comparison/bundle directories')
    args.output.mkdir(parents=True)
    args.models.mkdir(parents=True)
    protocol = read(Path('../docs/ml/TRANSFER_PROTOCOL.json'))
    for split, expected in protocol['split_sha256'].items():
        path = args.data/f'{split}.json'
        if (hashlib.sha256(path.read_bytes()).hexdigest() != expected
                and split_signature(read(path)) != protocol.get('portable_split_sha256', {}).get(split)):
            raise ValueError('Frozen canonical split changed')
    canonical = read(args.data/'classes.json')
    val_document = read(args.data/'val.json')
    cache = Path('evaluation-runs/transfer-comparison')
    selections = {}
    for name, run in runs.items():
        checkpoints = [run/'checkpoint_best_total.pth']
        if name == 'seg-nano-384':
            checkpoints += sorted(run.glob('checkpoint_*.ckpt'))+[run/'last.ckpt']
        options = []
        for checkpoint in checkpoints:
            if not checkpoint.exists():
                continue
            digest = hashlib.sha256(checkpoint.read_bytes()).hexdigest()
            cached = (cache/'nano-384-val-aa.json') if name == 'nano-384' else (cache/'nano-512-val.json') if name == 'nano-512' else cache/f'seg-epoch-{checkpoint.stem.removeprefix("checkpoint_")}-val.json'
            destination = args.output/f'{name}-{checkpoint.stem}-val.json'
            if cached.exists() and read(cached).get('checkpoint_sha256') == digest and read(cached).get('preprocessing') == 'RGB-square-PIL-bilinear-ImageNet-v1':
                result = read(cached)
                result['damage'] = score(val_document, 'damage', result['predictions'])
                result['calibration'] = calibrate(val_document, 'damage', result['predictions'])
                write(destination, result)
            else:
                result = evaluate(checkpoint, args.data/'val.json', destination, device='cpu')
            options.append((result['damage']['mAP50_95'], checkpoint, destination, result))
            gc.collect()
        _, checkpoint, val_path, result = max(options, key=lambda row: row[0])
        selections[name] = {'run': str(run), 'checkpoint': str(checkpoint), 'validation_file': str(val_path),
                            'validation': compact(result), 'calibration': result['calibration'],
                            'evaluated_validation_checkpoints': [{'checkpoint': str(c), 'mAP50_95': m} for m,c,_,_ in options]}
        print(json.dumps({'validation_selected': name, 'checkpoint': str(checkpoint), 'mAP50_95': result['damage']['mAP50_95']}), flush=True)
    # Selection is recorded before opening the common test labels for inference.
    write(args.output/'validation-selection.json', selections)
    medium = Path('datasets/raw/Car damages dataset/File1/img/Car damages 100.png')
    large = Path('evaluation-runs/hitl-final/large-photo.jpg')
    camera = Path('datasets/external/syndcar-v1/content/images/ID1_20240917_150956.png')
    with Image.open(camera) as source:
        source.convert('RGB').save(args.output/'camera-photo.jpg', quality=92)
    fixtures = {'medium': medium, 'large': large, 'camera': args.output/'camera-photo.jpg'}
    write(args.output/'camera-photo-attribution.json', {'source': str(camera), 'doi':'10.17632/hzpj48krdt.1',
          'license':'CC-BY-4.0','attribution':read(Path('datasets/external/syndcar-v1/audit.json'))['attribution'],
          'changes':'Re-encoded as JPEG quality 92, unchanged dimensions; benchmark fixture only.'})
    for name, selection in selections.items():
        bundle = args.models/name
        existing = Path('models/transfer-nano-384/fp32') if name == 'nano-384' else Path('models/transfer-nano-512/fp32-v2') if name == 'nano-512' else None
        threshold = selection['calibration']['selected']['threshold']
        if existing and existing.exists():
            shutil.copytree(existing, bundle)
            manifest = read(bundle/'manifest.json')
            if manifest['damage_checkpoint_sha256'] != selection['validation']['checkpoint_sha256']:
                raise ValueError('Cached export checkpoint mismatch')
            manifest['threshold'] = threshold
            manifest['nms_threshold'] = .45
            manifest['production_approved'] = False
            write(bundle/'manifest.json', manifest)
        else:
            export(Path(selection['checkpoint']), args.part_checkpoint, bundle, list(fixtures.values()), threshold)
        selection['bundle'] = str(bundle)
        selection['cpu'] = {}
        for label, photo in fixtures.items():
            target = args.output/f'{name}-cpu-{label}.json'
            subprocess.run([str(args.runtime_python), '-m', 'ml.transfer_benchmark', '--bundle', str(bundle), '--image', str(photo), '--output', str(target)], check=True)
            selection['cpu'][label] = read(target)
    # Re-measure the historical model in the same quiet CPU setting and process isolation.
    baseline_cpu = {}
    for label, photo in fixtures.items():
        target = args.output/f'baseline-cpu-{label}.json'
        subprocess.run([str(args.runtime_python), '-m', 'ml.benchmark', '--bundle', 'models/hitl-416', '--image', str(photo), '--output', str(target)], check=True)
        baseline_cpu[label] = read(target)
    envelope = protocol['local_cpu_selection_envelope']
    eligible = {name:s for name,s in selections.items() if max(m['photo_pipeline_ms_p95'] for m in s['cpu'].values()) <= envelope['maximum_photo_p95_ms']
                and max(m['peak_process_mib'] for m in s['cpu'].values()) <= envelope['maximum_vision_process_mib']}
    best = max(eligible or selections, key=lambda n: selections[n]['validation']['damage']['mAP50_95'])
    decision = {'selected': best, 'basis':'Validation bbox mAP50:95 within declared local CPU envelope, before final test',
                'local_resource_eligible': list(eligible), 'production_approved':False}
    write(args.output/'decision-before-test.json', decision)
    for name, selection in selections.items():
        checkpoint = Path(selection['checkpoint'])
        test_path = args.output/f'{name}-test.json'
        result = evaluate(checkpoint, args.data/'test.json', test_path, device='cpu', masks=name.startswith('seg'))
        selection['test'] = compact(result)
        try:
            verify(Path(selection['bundle']), args.data/'test.json', test_path, args.output/f'{name}-onnx-test.json')
        except ValueError as error:
            selection['accuracy_check_error'] = str(error)
        selection['onnx_test'] = read(args.output/f'{name}-onnx-test.json')
        external = evaluate(checkpoint, Path('evaluation-runs/syndcar-audit/external.json'),
                            args.output/f'{name}-external.json', device='cpu')
        selection['external_shared_classes'] = compact(external)
        gc.collect()
    external_path = Path('evaluation-runs/syndcar-audit/external.json')
    dataset = CocoTasks(external_path, 416)
    dataset.categories = {c['id']:c for c in canonical['categories']}
    baseline, _ = load_checkpoint(args.part_checkpoint)
    external = baseline_evaluate(baseline, dataset, 'cpu')
    baseline_external = score(dataset.document, 'damage', external['predictions']['damage'])
    from .evaluate_baseline_runtime import evaluate as evaluate_baseline_runtime
    historical_test = read(Path('../docs/ml/TRANSFER_BASELINE.json'))
    baseline_test = compact(evaluate_baseline_runtime(Path('models/hitl-416'), args.data/'test.json', args.output/'baseline-onnx-test.json'))
    chosen = selections[best]['onnx_test']['api_quality_gated_operating_point']
    failures = []
    for field, minimum in [('precision',.8), ('recall',.8), ('mAP50_95',.4)]:
        if chosen[field] < minimum:
            failures.append({'metric':field,'observed':chosen[field],'minimum':minimum})
    report = {'source_revision':'9b38355', 'protocol':protocol, 'decision':decision,
              'baseline':{'test':baseline_test,'historical_frozen_torch_test':historical_test,
                          'cpu':baseline_cpu,'external_shared_classes':baseline_external},
              'candidates':selections,'release_gate_failures':failures,
              'production_approved':False,'deployment_performed':False,
              'limitations':['Historical test is reused for comparison, not a fresh production acceptance holdout.',
                            'No verified clean/non-vehicle negative set or human relationship accuracy benchmark.',
                            'SYNDCAR is correlated synthetic/staged imagery, two shared classes only.',
                            'CPU envelopes are local engineering assumptions; actual Railway quotas, JVM and E5/RAG overhead were not measured.']}
    write(args.output/'results.json', report)
    write(Path('../docs/ml/TRANSFER_RESULTS.json'), report)
    from .transfer_report import write_markdown
    write_markdown(report, Path('../docs/ml/TRANSFER_RESULTS.md'))
    print(json.dumps({'selected':best,'production_approved':False,'release_failures':failures}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--nano384', type=Path, default=Path('training-runs/rfdetr-nano-384-v3'))
    parser.add_argument('--nano512', type=Path, default=Path('training-runs/transfer-comparison/nano-512'))
    parser.add_argument('--seg', type=Path, default=Path('training-runs/transfer-comparison/seg-nano-384-v2'))
    parser.add_argument('--data', type=Path, default=Path('datasets/hitl-coco'))
    parser.add_argument('--part-checkpoint', type=Path, default=Path('training-runs/hitl-tiny-416/best.pth'))
    parser.add_argument('--output', type=Path, default=Path('evaluation-runs/transfer-final'))
    parser.add_argument('--models', type=Path, default=Path('models/transfer-final'))
    parser.add_argument('--runtime-python', type=Path, default=Path(sys.executable))
    parser.add_argument('--wait', action='store_true')
    main(parser.parse_args())
