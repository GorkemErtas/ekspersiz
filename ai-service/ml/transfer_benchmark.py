"""Fresh-process CPU benchmark of the complete two-model photo pipeline, without Torch."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time

import numpy as np

from app.vision.ensemble import EnsembleBackend
from app.vision.processing import decode_image, quality, match_parts
from .benchmark import peak_memory_mib


def load_candidate(bundle):
    manifest = json.loads((bundle/'manifest.json').read_text(encoding='utf-8'))
    catalog = json.loads((bundle/'classes.json').read_text(encoding='utf-8'))
    for name, key in [('damage.onnx', 'damage_sha256'), ('part.onnx', 'part_sha256'), ('classes.json', 'catalog_sha256')]:
        if hashlib.sha256((bundle/name).read_bytes()).hexdigest() != manifest[key]:
            raise ValueError('Candidate checksum mismatch')
    categories = {t: sorted((c for c in catalog['categories'] if c['task'] == t), key=lambda c: c['task_index']) for t in ('damage', 'part')}
    return EnsembleBackend(bundle, manifest, categories), manifest


def benchmark(bundle, image, output, repeats=20):
    begin = time.perf_counter()
    backend, manifest = load_candidate(bundle)
    load_ms = (time.perf_counter()-begin)*1000
    content = image.read_bytes()
    durations = []
    for step in range(repeats+2):
        start = time.perf_counter()
        photo = decode_image(content)
        quality_result = quality(photo)
        damage, parts = backend.detect(photo)
        for detection in damage:
            match_parts(detection, parts)
        elapsed = (time.perf_counter()-start)*1000
        if step >= 2:
            durations.append(elapsed)
        counts = {'damage': len(damage), 'part': len(parts)}
        del photo, damage, parts
    report = {'bundle': str(bundle), 'model_version': manifest['model_version'], 'input_sizes': manifest['input_sizes'],
              'threads': 2, 'session_load_ms': load_ms, 'repeats': repeats,
              'thresholds': {'damage': manifest['threshold'], 'part': manifest['part_threshold']},
              'photo_pipeline_ms_median': float(np.median(durations)),
              'photo_pipeline_ms_p95': float(np.percentile(durations, 95)),
              'peak_process_mib': peak_memory_mib(), 'torch_imported': 'torch' in sys.modules,
              'detections': counts, 'photometric_suitable': quality_result['suitable'],
              'includes': ['decode', 'photometric_quality', 'both_preprocessing', 'two_model_forward', 'decoding', 'part_nms', 'part_matching'],
              'note': 'Local isolated CPU measurement; excludes JVM, E5/RAG, network, Gemini and actual Railway quotas.'}
    if report['torch_imported']:
        raise RuntimeError('Benchmark process must not import PyTorch')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report), flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repeats', type=int, default=20)
    args = parser.parse_args()
    benchmark(args.bundle, args.image, args.output, args.repeats)
