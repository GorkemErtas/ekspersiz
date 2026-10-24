"""Recheck reviewed part compatibility without retraining or changing damage selection."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from .transfer_verify import verify
from .transfer_report import write_markdown
from .evaluate_baseline_runtime import evaluate as evaluate_baseline


def read(path):
    return path.read_text(encoding='utf-8')


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def review(args):
    if args.output.exists() or args.models.exists():
        raise ValueError('Use new review result and immutable bundle directories')
    report = json.loads(read(args.source))
    args.output.mkdir(parents=True)
    args.models.mkdir(parents=True)
    baseline_bundle = Path('models/hitl-416')
    baseline_manifest = json.loads(read(baseline_bundle/'manifest.json'))
    assert baseline_manifest['nms_threshold'] == .45
    historical = report['baseline']['test']
    baseline_runtime = evaluate_baseline(baseline_bundle, args.data/'test.json', args.output/'baseline-onnx-test.json')
    report['baseline']['historical_frozen_torch_test'] = historical
    report['baseline']['test'] = {k:v for k,v in baseline_runtime.items() if k != 'predictions'}
    part_reference = baseline_runtime['part']
    source_output = args.source.parent
    fixtures = {
        'medium': Path('datasets/raw/Car damages dataset/File1/img/Car damages 100.png'),
        'camera': source_output/'camera-photo.jpg',
        'large': Path('evaluation-runs/hitl-final/large-photo.jpg'),
    }
    review = {'source_result': str(args.source),
              'source_result_sha256': hashlib.sha256(args.source.read_bytes()).hexdigest(),
              'reason': 'Preserve the historical part model NMS 0.45; initial ensemble exports used 0.50.',
              'damage_training_selection_and_postprocessing_changed': False,
              'baseline_nms_threshold': baseline_manifest['nms_threshold'], 'part_metric_differences': {},
              'reference': 'Fresh original unified ONNX runtime, not frozen historical Torch predictions',
              'historical_torch_vs_original_onnx_part_difference': {
                  key: baseline_runtime['part'][key]-historical['part'][key]
                  for key in ('mAP50_95','mAP50','precision','recall','true_positive','false_positive')}}
    for name, selection in report['candidates'].items():
        bundle = args.models/name
        shutil.copytree(Path(selection['bundle']), bundle)
        manifest = json.loads(read(bundle/'manifest.json'))
        if manifest['production_approved'] is not False:
            raise ValueError('Experimental review must not activate models')
        manifest['nms_threshold'] = baseline_manifest['nms_threshold']
        manifest['part_threshold'] = baseline_manifest['threshold']
        write(bundle/'manifest.json', manifest)
        selection['bundle'] = str(bundle)
        result_path = args.output/f'{name}-onnx-test.json'
        result = verify(bundle, args.data/'test.json', source_output/f'{name}-test.json', result_path)
        delta = {key: abs(result['part'][key]-part_reference[key])
                 for key in ('mAP50_95', 'mAP50', 'precision', 'recall')}
        if not all(value < 1e-4 for value in delta.values()):
            raise ValueError(f'Part model regression: {delta}')
        review['part_metric_differences'][name] = delta
        selection['onnx_test'] = result
        selection.pop('accuracy_check_error', None)
        selection['cpu'] = {}
        for label, photo in fixtures.items():
            target = args.output/f'{name}-cpu-{label}.json'
            subprocess.run([str(args.runtime_python), '-m', 'ml.transfer_benchmark', '--bundle', str(bundle),
                            '--image', str(photo), '--output', str(target)], check=True)
            selection['cpu'][label] = json.loads(read(target))
    for label, photo in fixtures.items():
        target = args.output/f'baseline-cpu-{label}.json'
        subprocess.run([str(args.runtime_python), '-m', 'ml.benchmark', '--bundle', str(baseline_bundle),
                        '--image', str(photo), '--output', str(target)], check=True)
        report['baseline']['cpu'][label] = json.loads(read(target))
    review['fixtures'] = {name: {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                          for name,path in fixtures.items()}
    report['part_compatibility_review'] = review
    # Only part NMS changed. Keep the original pre-test selection; do not re-select on test.
    envelope = report['protocol']['local_cpu_selection_envelope']
    selected_cpu = report['candidates'][report['decision']['selected']]['cpu']
    if any(row['photo_pipeline_ms_p95'] > envelope['maximum_photo_p95_ms']
           or row['peak_process_mib'] > envelope['maximum_vision_process_mib'] for row in selected_cpu.values()):
        raise ValueError('Reviewed selection no longer fits the declared local resource envelope')
    write(args.output/'results.json', report)
    write(Path('../docs/ml/TRANSFER_RESULTS.json'), report)
    write_markdown(report, Path('../docs/ml/TRANSFER_RESULTS.md'))
    print(json.dumps({'part_compatibility': 'passed', 'selected': report['decision']['selected'],
                      'production_approved': False}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('evaluation-runs/transfer-final/results.json'))
    parser.add_argument('--output', type=Path, default=Path('evaluation-runs/transfer-reviewed-v2'))
    parser.add_argument('--models', type=Path, default=Path('models/transfer-reviewed-v2'))
    parser.add_argument('--data', type=Path, default=Path('datasets/hitl-coco'))
    parser.add_argument('--runtime-python', type=Path, default=Path('venv/Scripts/python.exe'))
    review(parser.parse_args())
