"""Audit licensed external synthetic data; isolate only semantically shared damage labels."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from .dataset import image_hash


def audit(source, canonical, output):
    names = {0: 'Broken_Glass', 1: 'Cracks', 2: 'Scratches', 3: 'Broken_Lights'}
    catalog = json.loads((canonical/'classes.json').read_text(encoding='utf-8'))
    by_name = {c['name']: c for c in catalog['categories']}
    mapping = {1: by_name['Cracked'], 2: by_name['Scratch']}
    source_audit = json.loads((source/'audit.json').read_text(encoding='utf-8'))
    raw = source/'content/images'
    labels = source/'content/labels_damage'
    if '1: Cracks' not in (source/'content/data_damage.yaml').read_text(encoding='utf-8') or '2: Scratches' not in (source/'content/data_damage.yaml').read_text(encoding='utf-8'):
        raise ValueError('Publisher source class definitions changed')
    existing = set()
    for split in ('train', 'val', 'test'):
        doc = json.loads((canonical/f'{split}.json').read_text(encoding='utf-8'))
        existing.update(r['pixel_sha256'] for r in doc['images'])
    images, annotations = [], []
    counts = Counter()
    cameras = Counter()
    overlap, clipped = [], []
    fingerprint = hashlib.sha256()
    preview = Image.new('RGB', (1000, 800), 'white')
    for index, path in enumerate(sorted(raw.iterdir())):
        with Image.open(path) as source_image:
            source_image.load()
            image = source_image.convert('RGB')
        w, h = image.size
        content_hash = hashlib.sha256(f'{w}:{h}:'.encode()+image.tobytes()).hexdigest()
        if content_hash in existing:
            overlap.append(path.name)
        text = (labels/(path.stem+'.txt')).read_text(encoding='utf-8')
        fingerprint.update(path.name.encode()+bytes.fromhex(content_hash)+hashlib.sha256(text.encode()).digest())
        camera = path.name.split('_')[0]
        cameras[camera] += 1
        row = {'id': index+1, 'file_name': path.name, 'width': w, 'height': h, 'tasks': ['damage'],
               'camera': camera, 'pixel_sha256': content_hash, 'dhash': image_hash(image)}
        images.append(row)
        draw = ImageDraw.Draw(image) if index in (0, 60, 120, 180) else None
        for line in text.splitlines():
            if not line.strip():
                continue
            values = list(map(float, line.split()))
            if len(values) != 5 or not all(np.isfinite(values)) or values[0] not in names:
                raise ValueError(f'Invalid publisher bbox: {path.name}: {line}')
            category, cx, cy, bw, bh = values
            if not (0 < bw <= 1 and 0 < bh <= 1 and 0 <= cx <= 1 and 0 <= cy <= 1):
                raise ValueError('Invalid normalized bbox')
            x1, y1, x2, y2 = (cx-bw/2)*w, (cy-bh/2)*h, (cx+bw/2)*w, (cy+bh/2)*h
            if x1 < 0 or y1 < 0 or x2 > w or y2 > h:
                clipped.append({'image': path.name, 'source_class': names[int(category)]})
            x1, y1, x2, y2 = max(0., x1), max(0., y1), min(float(w), x2), min(float(h), y2)
            counts[names[int(category)]] += 1
            if draw is not None:
                draw.rectangle((x1, y1, x2, y2), outline='red' if category in mapping else 'yellow', width=8)
                draw.text((x1, y1), names[int(category)], fill='red' if category in mapping else 'yellow', stroke_width=2)
            if int(category) in mapping:
                annotations.append({'id': len(annotations)+1, 'image_id': row['id'], 'category_id': mapping[int(category)]['id'],
                                    'bbox': [x1, y1, x2-x1, y2-y1], 'area': (x2-x1)*(y2-y1), 'iscrowd': 0,
                                    'source_class': names[int(category)]})
        if draw is not None:
            slot = (0, 60, 120, 180).index(index)
            image.thumbnail((498, 398))
            preview.paste(image, ((slot%2)*500, (slot//2)*400))
    if overlap:
        raise ValueError(f'External holdout overlaps HITL: {overlap}')
    output.mkdir(parents=True, exist_ok=True)
    preview.save(output/'preview.jpg')
    doc = {'info': {'source_root': str(raw.resolve()), 'source': source_audit['source'],
                    'license': 'CC-BY-4.0', 'use': 'external synthetic holdout, shared labels only; never training'},
           'categories': list(mapping.values()), 'images': images, 'annotations': annotations}
    (output/'external.json').write_text(json.dumps(doc, ensure_ascii=False), encoding='utf-8')
    report = {'source': source_audit['source'], 'doi': source_audit['doi'], 'license': 'CC-BY-4.0',
              'archive_sha256': source_audit['archive_sha256'], 'images': len(images), 'source_annotations': dict(counts),
              'shared_annotations': len(annotations), 'source_to_canonical_mapping': {names[k]: v['name'] for k,v in mapping.items()},
              'unmapped_classes': ['Broken_Glass', 'Broken_Lights'], 'cameras': dict(cameras),
              'exact_pixel_overlap_with_hitl': len(overlap), 'fingerprint': fingerprint.hexdigest(),
              'clipped_source_boxes': clipped, 'training_use': False,
              'images_without_shared_damage_annotations': sum(not any(a['image_id'] == r['id'] for a in annotations) for r in images),
              'images_above_api_24mp_limit': sum(r['width']*r['height'] > 24_000_000 for r in images),
              'attribution': source_audit['attribution'],
              'limitations': ['Synthetic/staged damage is a separate domain; it does not establish real-world production accuracy.',
                             'Only Cracks/Cracked and Scratches/Scratch are semantically shared. Other predictions/labels are excluded from shared-label scores.',
                             'Absence of these two labels does not mean a vehicle has no damage.',
                             'Camera IDs are not independent vehicle IDs; near-adjacent views are correlated.']}
    (output/'audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report), flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('datasets/external/syndcar-v1'))
    parser.add_argument('--canonical', type=Path, default=Path('datasets/hitl-coco'))
    parser.add_argument('--output', type=Path, default=Path('evaluation-runs/syndcar-audit'))
    args = parser.parse_args()
    audit(args.source, args.canonical, args.output)
