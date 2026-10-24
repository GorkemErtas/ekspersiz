"""Read-only Supervisely audit and deterministic, task-aware COCO conversion."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import random

import numpy as np
from PIL import Image, ImageDraw

DAMAGE_NAMES = frozenset(('Missing part', 'Broken part', 'Scratch', 'Cracked',
                          'Dent', 'Flaking', 'Paint chip', 'Corrosion'))
PART_NAMES = frozenset(('Quarter-panel', 'Front-wheel', 'Back-window', 'Trunk',
    'Front-door', 'Rocker-panel', 'Grille', 'Windshield', 'Front-window', 'Back-door',
    'Headlight', 'Back-wheel', 'Back-windshield', 'Hood', 'Fender', 'Tail-light',
    'License-plate', 'Front-bumper', 'Back-bumper', 'Mirror', 'Roof'))
TRANSLATIONS = {
    'Missing part': 'Eksik parça', 'Broken part': 'Kırık parça', 'Scratch': 'Çizik',
    'Cracked': 'Çatlak', 'Dent': 'Göçük', 'Flaking': 'Boya soyulması',
    'Paint chip': 'Boya kopması', 'Corrosion': 'Korozyon',
    'Quarter-panel': 'Arka yan panel', 'Front-wheel': 'Ön tekerlek',
    'Back-window': 'Arka kapı camı', 'Trunk': 'Bagaj kapağı', 'Front-door': 'Ön kapı',
    'Rocker-panel': 'Marşpiyel', 'Grille': 'Izgara', 'Windshield': 'Ön cam',
    'Front-window': 'Ön kapı camı', 'Back-door': 'Arka kapı', 'Headlight': 'Far',
    'Back-wheel': 'Arka tekerlek', 'Back-windshield': 'Arka cam', 'Hood': 'Kaput',
    'Fender': 'Çamurluk', 'Tail-light': 'Stop lambası', 'License-plate': 'Plaka',
    'Front-bumper': 'Ön tampon', 'Back-bumper': 'Arka tampon', 'Mirror': 'Ayna', 'Roof': 'Tavan',
}


def task_for(names):
    names = set(names)
    if names and names <= DAMAGE_NAMES:
        return 'damage'
    if names and names <= PART_NAMES:
        return 'part'
    raise ValueError(f'Unknown or mixed semantic catalog: {sorted(names)}')


def digest(content):
    return hashlib.sha256(content).hexdigest()


def image_hash(image):
    a = np.asarray(image.convert('L').resize((9, 8)))
    return int.from_bytes(np.packbits(a[:, 1:] > a[:, :-1]).tobytes(), 'big')


def polygon(obj, width, height):
    if obj.get('geometryType') != 'polygon':
        raise ValueError('Unsupported annotation geometry')
    rings = [obj['points']['exterior'], *obj['points'].get('interior', [])]
    for ring in rings:
        if len(ring) < 3 or any(len(p) != 2 or not all(math.isfinite(v) for v in p) for p in ring):
            raise ValueError('Invalid polygon vertices')
        if any(not (0 <= x <= width and 0 <= y <= height) for x, y in ring):
            raise ValueError('Polygon outside image bounds')
    exterior = rings[0]
    x1, y1 = map(min, zip(*exterior))
    x2, y2 = map(max, zip(*exterior))
    if x2 <= x1 or y2 <= y1:
        raise ValueError('Degenerate bounding box')
    mask = Image.new('1', (width, height))
    draw = ImageDraw.Draw(mask)
    draw.polygon([tuple(p) for p in exterior], fill=1)
    for ring in rings[1:]:
        draw.polygon([tuple(p) for p in ring], fill=0)
    pixels = np.asarray(mask, dtype=np.uint8)
    if not pixels.any():
        raise ValueError('Zero-area polygon')
    # Uncompressed COCO RLE preserves holes; detection evaluation uses the bbox.
    flat = pixels.flatten(order='F')
    switches = np.flatnonzero(np.diff(flat)) + 1
    counts = np.diff(np.r_[0, switches, len(flat)]).tolist()
    if flat[0]:
        counts.insert(0, 0)
    return [x1, y1, x2-x1, y2-y1], int(pixels.sum()), {'size': [height, width], 'counts': counts}


def audit(raw: Path):
    rows, objects, errors, sources = [], [], [], []
    names_by_task = defaultdict(set)
    for meta_path in sorted(raw.glob('**/meta.json')):
        source = meta_path.parent
        meta = json.loads(meta_path.read_text(encoding='utf-8-sig'))
        catalog = {x['title']: x for x in meta['classes']}
        task = task_for(catalog)
        names_by_task[task].update(catalog)
        annotations = sorted(source.glob('**/ann/*.json'))
        sources.append({'directory': source.relative_to(raw).as_posix(), 'task': task,
                        'images': len(list(source.glob('**/img/*'))), 'annotations': len(annotations),
                        'meta_sha256': digest(meta_path.read_bytes())})
        annotated_paths = set()
        for ann_path in annotations:
            image_path = ann_path.parent.parent / 'img' / ann_path.name.removesuffix('.json')
            annotated_paths.add(image_path)
            try:
                ann = json.loads(ann_path.read_text(encoding='utf-8-sig'))
                with Image.open(image_path) as img:
                    img.load()
                    image = img.convert('RGB')
                w, h = image.size
                if ann.get('size', {}).get('width', w) != w or ann.get('size', {}).get('height', h) != h:
                    raise ValueError('Annotation/image dimensions disagree')
                local_objects = []
                for obj in ann['objects']:
                    name = obj['classTitle']
                    if name not in catalog or obj.get('classId') != catalog[name]['id']:
                        raise ValueError('Annotation class title/id disagrees with meta.json')
                    if not obj.get('labelerLogin'):
                        raise ValueError('Missing human annotation provenance')
                    bbox, area, segmentation = polygon(obj, w, h)
                    local_objects.append({'name': name, 'task': task, 'bbox': bbox,
                        'area': area, 'segmentation': segmentation,
                        'source_object_id': obj.get('id'), 'labeler': obj['labelerLogin']})
                row = {'id': len(rows)+1, 'file_name': image_path.relative_to(raw).as_posix(),
                    'width': w, 'height': h, 'tasks': [task], 'labels': sorted({o['name'] for o in local_objects}),
                    'sha256': digest(image_path.read_bytes()),
                    'pixel_sha256': digest(f'{w}:{h}:'.encode()+image.tobytes()),
                    'annotation_sha256': digest(ann_path.read_bytes()),
                    'dhash': image_hash(image), 'annotation_file': ann_path.relative_to(raw).as_posix()}
                rows.append(row)
                objects.extend(dict(o, image_id=row['id']) for o in local_objects)
            except (ValueError, KeyError, OSError, TypeError) as exc:
                errors.append({'file': ann_path.relative_to(raw).as_posix(), 'error': str(exc)})
        for image_path in source.glob('**/img/*'):
            if image_path not in annotated_paths:
                errors.append({'file': image_path.relative_to(raw).as_posix(), 'error': 'Missing annotation'})
    if not sources:
        raise ValueError('No Supervisely meta.json sources found')
    categories = []
    for task in ('damage', 'part'):
        for index, name in enumerate(sorted(names_by_task[task])):
            categories.append({'id': len(categories)+1, 'name': name, 'task': task,
                'task_index': index, 'code': name.upper().replace('-', '_').replace(' ', '_'),
                'display_tr': TRANSLATIONS[name]})
    return rows, objects, categories, errors, sources


def group_images(rows, distance=4):
    parent = list(range(len(rows)))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for i, a in enumerate(rows):
        for j in range(i):
            b = rows[j]
            # Conservative near-duplicate grouping prevents altered exports leaking.
            if a['pixel_sha256'] == b['pixel_sha256'] or (a['dhash'] ^ b['dhash']).bit_count() <= distance:
                parent[find(i)] = find(j)
    groups = defaultdict(list)
    for i, row in enumerate(rows):
        groups[find(i)].append(row)
    return list(groups.values())


def merge_identical_images(rows, objects):
    """Only exact decoded pixel identity can join complementary task labels."""
    canonical, mapping = {}, {}
    for row in rows:
        key = row['pixel_sha256']
        if key not in canonical:
            canonical[key] = dict(row, source_files=[row['file_name']],
                                  source_annotation_hashes=[row['annotation_sha256']])
        else:
            previous = canonical[key]
            if set(previous['tasks']) & set(row['tasks']):
                raise ValueError('Duplicate image with overlapping task coverage needs explicit annotation review')
            previous['tasks'] = sorted(set(previous['tasks']) | set(row['tasks']))
            previous['labels'] = sorted(set(previous['labels']) | set(row['labels']))
            previous['source_files'].append(row['file_name'])
            previous['source_annotation_hashes'].append(row['annotation_sha256'])
        mapping[row['id']] = canonical[key]['id']
    for obj in objects:
        obj['image_id'] = mapping[obj['image_id']]
    return list(canonical.values())


def split_groups(groups, seed=2026):
    rng = random.Random(seed)
    rng.shuffle(groups)
    totals = Counter(name for g in groups for r in g for name in r['labels'])
    groups.sort(key=lambda g: (-sum(1/totals[n] for r in g for n in r['labels']), -len(g)))
    counts = {s: Counter() for s in ('train','val','test')}
    sizes = Counter()
    total = sum(len(g) for g in groups)
    ratios = {'train': .8, 'val': .1, 'test': .1}
    for group in groups:
        labels = Counter(n for r in group for n in r['labels'])
        def score(split):
            target = ratios[split]
            size_deficit = (target*total - sizes[split]) / max(target*total, 1)
            label_deficit = sum((target*totals[n]-counts[split][n]) / max(target*totals[n],1)
                                for n in labels) / max(len(labels),1)
            return size_deficit + label_deficit
        split = max(ratios, key=score)
        key = min(r['pixel_sha256'] for r in group)
        for row in group:
            row['split'] = split
            row['group_id'] = key
        counts[split].update(labels)
        sizes[split] += len(group)
    return dict(sizes)


def convert(raw: Path, output: Path, seed=2026, quarantine=False):
    raw, output = raw.resolve(), output.resolve()
    if output == raw or raw in output.parents:
        raise ValueError('Output must not be inside immutable raw dataset')
    rows, objects, categories, errors, sources = audit(raw)
    validated_source_images = len(rows)
    rows = merge_identical_images(rows, objects)
    output.mkdir(parents=True, exist_ok=True)
    groups = group_images(rows)
    sizes = split_groups(groups, seed)
    category_ids = {c['name']: c['id'] for c in categories}
    stats = {}
    for c in categories:
        matching = [o for o in objects if o['name'] == c['name']]
        stats[c['name']] = {'task': c['task'], 'images': len({o['image_id'] for o in matching}),
                           'annotations': len(matching), 'splits': {}}
    for split in sizes:
        ids = {r['id'] for r in rows if r['split'] == split}
        for c in categories:
            matches = [o for o in objects if o['name'] == c['name'] and o['image_id'] in ids]
            stats[c['name']]['splits'][split] = {'images': len({o['image_id'] for o in matches}), 'annotations': len(matches)}
    report = {'source_root': str(raw), 'sources': sources, 'source_images': sum(s['images'] for s in sources),
        'validated_source_images': validated_source_images, 'images': len(rows), 'annotations': len(objects),
        'errors': errors, 'quarantined_images': len(errors), 'seed': seed, 'split_sizes': sizes,
        'class_counts': stats, 'groups': len(groups), 'largest_group': max(map(len,groups),default=0),
        'merged_complementary_images': sum(len(r['source_files'])>1 for r in rows),
        'task_coverage': dict(Counter(t for r in rows for t in r['tasks'])),
        'paired_task_images': sum(len(r['tasks']) == 2 for r in rows),
        'mask_policy': 'Supervisely human-attributed polygons are authoritative. Human/machine mask directories are alternative raster exports, not independent labels; never used as extra training samples.',
        'limitations': ['No capture/vehicle identity metadata; perceptual grouping cannot prove all related vehicles are separated.',
            'No clean-car/negative-damage ground truth; absence of detections cannot certify no visible damage.',
            'Paired images provide both tasks, but explicit damage-instance/part-instance relationships are absent.']}
    (output/'audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    if errors and not quarantine:
        raise ValueError(f'{len(errors)} invalid source files; see audit.json. Use explicit --quarantine-invalid to exclude entire invalid images.')
    catalog = {'schema_version': 'hitl-v1', 'categories': categories}
    (output/'classes.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
    for split in ('train','val','test'):
        images = [r for r in rows if r['split'] == split]
        ids = {r['id'] for r in images}
        annotations = [dict(o, id=i+1, category_id=category_ids[o['name']], iscrowd=0)
                       for i,o in enumerate(objects) if o['image_id'] in ids]
        coco = {'info': {'source_root': str(raw), 'schema_version': 'hitl-v1', 'seed': seed},
                'images': images, 'annotations': annotations, 'categories': categories}
        (output/f'{split}.json').write_text(json.dumps(coco,ensure_ascii=False),encoding='utf-8')
    # Human review contact sheets use only derived output; raw remains untouched.
    for task in ('damage','part'):
        for row in [r for r in rows if task in r['tasks']][:4]:
            with Image.open(raw/row['file_name']) as im:
                im = im.convert('RGB')
            d = ImageDraw.Draw(im)
            for o in objects:
                if o['image_id'] == row['id']:
                    x,y,w,h = o['bbox']
                    d.rectangle((x,y,x+w,y+h), outline='red', width=2)
                    d.text((x,y), o['name'], fill='red')
            im.thumbnail((900,900))
            im.save(output/f'preview-{task}-{row["id"]}.jpg')
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--raw', type=Path, default=Path('datasets/raw'))
    p.add_argument('--output', type=Path, default=Path('datasets/hitl-coco'))
    p.add_argument('--seed', type=int, default=2026)
    p.add_argument('--quarantine-invalid', action='store_true')
    a = p.parse_args()
    r = convert(a.raw, a.output, a.seed, a.quarantine_invalid)
    print(json.dumps({k:r[k] for k in ('images','annotations','split_sizes','groups','paired_task_images','quarantined_images')}))


if __name__ == '__main__':
    main()
