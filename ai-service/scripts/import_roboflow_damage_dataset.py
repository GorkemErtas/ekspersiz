"""Immutable, audited segmentation-to-detection import; never starts training."""
from __future__ import annotations

import argparse
from collections import Counter
import json
import importlib.metadata
from pathlib import Path
import random
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import yaml
from PIL import Image, ImageDraw
from experiments.config import load_yaml
from experiments.roboflow_dataset import (
    IMAGE_EXTENSIONS, MAPPING, SPLITS, digest_json, draw_sample, find_duplicates,
    image_signature, mapping, polygon_box, sha256, source_manifest, validate_experiment, write_json,
)

DEFAULT_SOURCE = ROOT/'datasets/raw/roboflow_car_damages_segmentation'
LOCAL_SOURCE = ROOT/'datasets/raw/cardd/roboflow_car_damages_segmentation'
DEFAULT_TARGET = ROOT/'datasets/vehicle_damage_detection_v3_rf'


def import_dataset(source: Path, target: Path, *, mapping_path: Path = MAPPING,
                   quarantine_list: Path | None = None, seed: int = 42) -> dict:
    source, target = source.resolve(), target.resolve()
    if target.exists():
        raise ValueError('Target already exists. Use a new target; imports never overwrite existing data.')
    if target.is_relative_to(source) or source.is_relative_to(target):
        raise ValueError('Source and target must be disjoint.')
    if target == (ROOT/'datasets/vehicle_damage_detection_v2').resolve():
        raise ValueError('Production CarDD dataset is protected.')
    contract = mapping(mapping_path)
    config = load_yaml(source/'data.yaml')
    if config.get('names') != contract['source_names'] or config.get('nc') != 11:
        raise ValueError('Source names/IDs do not exactly match the reviewed eleven-class mapping.')
    before = source_manifest(source)
    quarantine = set(json.loads(quarantine_list.read_text(encoding='utf-8'))) if quarantine_list else set()
    if any(not isinstance(k, str) for k in quarantine):
        raise ValueError('Quarantine list must contain source image keys.')
    records, problems, objects_by_key = [], [], {}
    counts = {split: Counter() for split in SPLITS}
    raw_counts = {split: Counter() for split in SPLITS}
    resolved_splits = {}
    for split, directory in SPLITS.items():
        declared = config.get(split)
        # Roboflow exports ../train/images beside train/, not one level above it.
        if declared not in (f'../{directory}/images', f'{directory}/images'):
            raise ValueError(f'Unreviewed source split layout: {split}={declared}')
        images_root, labels_root = source/directory/'images', source/directory/'labels'
        if not images_root.is_dir() or not labels_root.is_dir():
            raise ValueError(f'Missing source split directories: {directory}')
        resolved_splits[split] = {'declared': declared, 'resolved_relative': f'{directory}/images'}
        images = sorted(p for p in images_root.rglob('*') if p.suffix.lower() in IMAGE_EXTENSIONS)
        labels = {p.relative_to(labels_root).with_suffix('').as_posix(): p for p in labels_root.rglob('*.txt')}
        stems = Counter(p.relative_to(images_root).with_suffix('').as_posix().lower() for p in images)
        image_stems = {p.relative_to(images_root).with_suffix('').as_posix() for p in images}
        for stem in sorted(set(labels) - image_stems):
            problems.append({'kind': 'label_without_image', 'path': labels[stem].relative_to(source).as_posix()})
        for path in images:
            relative = path.relative_to(images_root)
            stem = relative.with_suffix('').as_posix()
            label = labels.get(stem)
            key = path.relative_to(source).as_posix()
            record = {'key': key, 'split': split, 'relative_image': relative.as_posix(),
                      'image_sha256': sha256(path), 'status': 'imported', 'issues': [], 'classes': []}
            objects = []
            if stems[stem.lower()] > 1:
                record['issues'].append('colliding_image_stem')
            try:
                record.update(image_signature(path))
            except (OSError, ValueError, Image.DecompressionBombError) as error:
                record['issues'].append(f'image: {error}')
            if label is None:
                record['issues'].append('missing_label_not_assumed_negative')
            else:
                record['source_label'] = label.relative_to(source).as_posix()
                record['label_sha256'] = sha256(label)
                for number, line in enumerate(label.read_text(encoding='utf-8-sig').splitlines(), 1):
                    if not line.strip():
                        continue
                    try:
                        raw_class = int(line.split()[0])
                        if 0 <= raw_class < 11:
                            raw_counts[split][contract['model_names'][raw_class]] += 1
                        obj = polygon_box(line, 11)
                        objects.append(obj)
                    except (ValueError, OverflowError) as error:
                        record['issues'].append(f'line {number}: {error}')
            if key in quarantine:
                record['issues'].append('explicit_whole_image_quarantine')
            if record['issues']:
                record['status'] = 'quarantined'
            else:
                record['classes'] = [obj[0] for obj in objects]
                counts[split].update(contract['model_names'][obj[0]] for obj in objects)
                objects_by_key[key] = objects
            records.append(record)
    if quarantine - {r['key'] for r in records}:
        raise ValueError('Quarantine list contains unknown image keys.')
    print(f'Scanned {len(records)} images; checking pixel/perceptual duplicates...', flush=True)
    pairs = find_duplicates(records)
    # Preserve source splits, but exclude BOTH sides of exact cross-split leakage.
    # Never choose a favored split or drop only selected annotations.
    leaked = {key for pair in pairs if pair['cross_split'] and pair['kind']=='exact'
              for key in (pair['left'], pair['right'])}
    for record in records:
        if record['key'] in leaked:
            record['issues'].append('exact_cross_split_duplicate_whole_image_quarantine')
            record['status'] = 'quarantined'
    counts = {split: Counter() for split in SPLITS}
    for record in records:
        if record['status'] == 'imported':
            counts[record['split']].update(contract['model_names'][cid] for cid in record['classes'])
    retained = {r['key'] for r in records if r['status']=='imported'}
    for pair in pairs:
        pair['both_imported'] = {pair['left'], pair['right']}.issubset(retained)
    if source_manifest(source) != before:
        raise ValueError('Source changed during inspection; aborting import.')
    target.mkdir(parents=True)
    for split in SPLITS:
        for group in ('images', 'labels', 'source-segmentation'):
            (target/group/split).mkdir(parents=True)
    for record in records:
        if record['status'] != 'imported':
            continue
        relative = Path(record['relative_image'])
        image_out = target/'images'/record['split']/relative
        label_out = target/'labels'/record['split']/relative.with_suffix('.txt')
        segment_out = target/'source-segmentation'/record['split']/relative.with_suffix('.txt')
        for path in (image_out, label_out, segment_out):
            path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source/record['key'], image_out)
        shutil.copyfile(source/record['source_label'], segment_out)
        label_out.write_text(''.join(f'{cid} ' + ' '.join(f'{v:.10f}' for v in box) + '\n'
                                    for cid, box, _ in objects_by_key[record['key']]), encoding='utf-8')
    yaml_config = {s: f'images/{s}' for s in SPLITS}
    yaml_config.update(nc=11, names=contract['model_names'])
    (target/'data.yaml').write_text(yaml.safe_dump(yaml_config, sort_keys=False), encoding='utf-8')
    metadata = target/'source-metadata'
    metadata.mkdir()
    for filename in ('data.yaml', 'README.dataset.txt', 'README.roboflow.txt'):
        if (source/filename).is_file():
            shutil.copyfile(source/filename, metadata/filename)
    shutil.copyfile(mapping_path, metadata/'class-mapping.yaml')
    review_root = target/'review-samples'
    review_root.mkdir()
    candidates = [r for r in records if r['status'] == 'imported']
    random.Random(seed).shuffle(candidates)
    selected, covered = {}, set()
    for record in candidates:
        keys = {(record['split'], cid) for cid in record['classes'] or [-1]}
        if keys - covered or not record['classes']:
            selected[record['key']] = record
            covered.update(keys)
    samples = []
    for index, record in enumerate(selected.values()):
        output = review_root/f'{index:03d}-{record["split"]}.jpg'
        draw_sample(source/record['key'], output, objects_by_key[record['key']], contract['model_names'])
        samples.append({'path': output.relative_to(target).as_posix(), 'source': record['key'],
                        'classes': sorted(set(record['classes']))})
    # Every cross-split similarity candidate has a side-by-side review artifact.
    for pair in pairs:
        if not pair['cross_split']:
            continue
        canvas = Image.new('RGB', (960, 410), 'white')
        draw = ImageDraw.Draw(canvas)
        for offset, key in ((0, pair['left']), (480, pair['right'])):
            with Image.open(source/key) as raw:
                photo = raw.convert('RGB')
            photo.thumbnail((470, 360))
            canvas.paste(photo, (offset, 45))
            draw.text((offset+5, 5), key[:64], fill='black')
            draw.text((offset+5, 20), f'{pair["kind"]} Hamming={pair["hamming"]}', fill='black')
        output = review_root/f'duplicate-{pair["id"]}.jpg'
        canvas.save(output)
        pair['review_image'] = output.relative_to(target).as_posix()
    names = contract['model_names']
    warnings = []
    for split in SPLITS:
        absent = [name for name in names if not counts[split][name]]
        if absent:
            warnings.append(f'{split}: absent classes {absent}; AP for absent test classes is undefined.')
    positive = [counts['train'][n] for n in names if counts['train'][n]]
    ratio = max(positive)/min(positive) if positive else None
    if ratio and ratio > 10:
        warnings.append(f'Train instance imbalance max/min={ratio:.2f}; no automatic oversampling or label merging.')
    report = {
        'schema_version': 1, 'experiment': contract['experiment'], 'seed': seed,
        'source_root': str(source), 'source_manifest': before, 'source_fingerprint': digest_json(before),
        'mapping_sha256': sha256(mapping_path), 'classes': names, 'split_resolution': resolved_splits,
        'tools': {'importer_sha256': sha256(Path(__file__)),
                  'validation_sha256': sha256(ROOT/'experiments/roboflow_dataset.py'),
                  'python': sys.version,
                  'packages': {name: importlib.metadata.version(name) for name in ('Pillow', 'numpy', 'PyYAML')}},
        'quarantine_list_sha256': sha256(quarantine_list) if quarantine_list else None,
        'source_class_counts': {s: {n: raw_counts[s][n] for n in names} for s in SPLITS},
        'class_counts': {s: {n: counts[s][n] for n in names} for s in SPLITS},
        'class_image_counts': {s: {name: sum(r['status']=='imported' and r['split']==s and cid in r['classes'] for r in records)
                                  for cid, name in enumerate(names)} for s in SPLITS},
        'images': {s: {'source': sum(r['split']==s for r in records),
                       'imported': sum(r['split']==s and r['status']=='imported' for r in records),
                       'quarantined': sum(r['split']==s and r['status']=='quarantined' for r in records),
                       'empty_labels': sum(r['split']==s and r['status']=='imported' and not r['classes'] for r in records)} for s in SPLITS},
        'records': records, 'orphan_labels': problems, 'duplicate_pairs': pairs,
        'duplicate_method': {'exact': 'file SHA256 or decoded RGB pixels + dimensions',
                             'near': '63-bit DCT pHash Hamming <=6 and aspect-ratio difference <=10%; candidate, not proof',
                             'exact_cross_split_policy': 'quarantine all affected images in every split; do not reassign'},
        'warnings': warnings, 'train_instance_imbalance_ratio': ratio,
        'provenance': {'export_claim': config.get('roboflow'), 'verified_commercial_use': False,
                       'note': 'Export claims CC BY 4.0. Original ownership and annotation provenance unverified.'},
        'sample_details': samples, 'review_samples': [s['path'] for s in samples],
        'training_status': 'BLOCKED_PENDING_VISUAL_AND_LEAKAGE_REVIEW',
    }
    (target/'README.md').write_text(
        '# Roboflow damage detection V3 experiment\n\n'
        'Independent 11-class detection IDs; no production mapping. Source polygons are preserved '
        'in the raw source and source-segmentation/. Images are copied byte-for-byte, never moved.\n\n'
        'Cyan = source polygon; red = derived bounding box in review-samples/. '
        'Any invalid annotation quarantines the entire image, including its valid annotations. '
        'No annotations are silently dropped. Split membership is never shuffled.\n\n'
        'See import-report.json for distributions, quarantine, duplicates and source fingerprints. '
        'Near-duplicate candidates require human review. Both sides of exact cross-split duplicates '
        'are quarantined; any remaining exact leakage blocks training. '
        'No commercial-use clearance is implied. Training is blocked until review.json is completed.\n\n'
        'Commands and evaluation protocol: [experiment runbook](../../../docs/ml/ROBOFLOW_DAMAGE_V3_EXPERIMENT.md).\n', encoding='utf-8')
    report['output_manifest'] = [{'path': p.relative_to(target).as_posix(), 'sha256': sha256(p)}
                                 for p in sorted(target.rglob('*')) if p.is_file()]
    write_json(target/'import-report.json', report)
    review = {'import_report_sha256': sha256(target/'import-report.json'), 'reviewer': '', 'reviewed_at': '',
              'annotations_accepted': False, 'quarantine_accepted': False, 'negative_images_checked': False,
              'imbalance_accepted': False, 'provenance_reviewed_for_research': False, 'reviewed_samples': [],
              'near_duplicate_decisions': {p['id']: {'decision': 'pending', 'reason': ''} for p in pairs if p['cross_split']}}
    write_json(target/'review.json', review)
    validate_experiment(target/'data.yaml')
    if source_manifest(source) != before:
        raise ValueError('Source changed during copy; training must remain blocked.')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--target', type=Path, default=DEFAULT_TARGET)
    parser.add_argument('--quarantine-list', type=Path)
    parser.add_argument('--seed', type=int, default=42)
    args = parser.parse_args()
    source = args.source or (DEFAULT_SOURCE if DEFAULT_SOURCE.is_dir() else LOCAL_SOURCE)
    report = import_dataset(source, args.target, quarantine_list=args.quarantine_list, seed=args.seed)
    print(json.dumps({k: report[k] for k in ('images', 'class_counts', 'warnings', 'training_status')}, indent=2))


if __name__ == '__main__':
    main()
