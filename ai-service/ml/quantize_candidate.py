"""Offline dynamic INT8 MatMul candidate; accuracy must be measured before selection."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def quantize(source, output):
    from onnxruntime.quantization import quantize_dynamic, QuantType
    if output.exists():
        raise ValueError('Use a new quantized candidate directory')
    manifest = json.loads((source/'manifest.json').read_text(encoding='utf-8'))
    if manifest.get('format') != 'ensemble-v1' or manifest.get('production_approved') is not False:
        raise ValueError('Quantize an unapproved offline ensemble candidate only')
    if hashlib.sha256((source/'damage.onnx').read_bytes()).hexdigest() != manifest['damage_sha256']:
        raise ValueError('Source graph checksum mismatch')
    # Failed conversions must not retain the source's usable manifest under an INT8 directory name.
    shutil.copytree(source, output, ignore=shutil.ignore_patterns('manifest.json'))
    quantized = output/'damage-int8.onnx'
    quantize_dynamic(str(source/'damage.onnx'), str(quantized), per_channel=True,
                     weight_type=QuantType.QInt8, op_types_to_quantize=['MatMul'],
                     extra_options={'MatMulConstBOnly': True})
    quantized.replace(output/'damage.onnx')
    manifest.update(model_version=manifest['model_version']+'-int8', production_approved=False,
                    quantization={'method': 'ORT dynamic INT8 constant-weight MatMul, per-channel',
                                  'source_fp32_sha256': manifest['damage_sha256'], 'validation_accuracy_required': True},
                    damage_sha256=hashlib.sha256((output/'damage.onnx').read_bytes()).hexdigest())
    # Floating-point tensor parity does not apply to quantization; retain it only as source provenance.
    manifest['source_fp32_parity'] = manifest.pop('parity')
    (output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    with (output/'licenses/NOTICE.md').open('a', encoding='utf-8') as stream:
        stream.write('Additional modification: dynamic per-channel INT8 quantization of constant-weight MatMul operators using ONNX Runtime (MIT).\n')
    print(json.dumps({'output': str(output), 'damage_bytes': (output/'damage.onnx').stat().st_size,
                      'source_bytes': (source/'damage.onnx').stat().st_size, 'production_approved': False}), flush=True)
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    quantize(args.source, args.output)
