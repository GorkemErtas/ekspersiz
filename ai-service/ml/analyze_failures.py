"""Reproducible label/scale audit. Flags are review candidates, not automatic relabels."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def audit(data, output, previews=None):
    documents = {split: json.loads((data / f'{split}.json').read_text(encoding='utf-8'))
                 for split in ('train', 'val', 'test')}
    categories = {c['id']: c for c in documents['train']['categories']}
    sizes = defaultdict(list)
    counts = defaultdict(Counter)
    images_per_class = defaultdict(set)
    suspicious = []
    split_rows = {}
    for split, document in documents.items():
        rows = {r['id']: r for r in document['images']}
        by_image = defaultdict(list)
        for ann in document['annotations']:
            row = rows[ann['image_id']]
            x, y, w, h = ann['bbox']
            cat = categories[ann['category_id']]
            counts[cat['name']][split] += 1
            images_per_class[cat['name']].add(row['id'])
            for resolution in (384, 416, 512, 640):
                ratio = resolution / max(row['width'], row['height'])
                sizes[cat['name'], resolution].append((min(w, h) * ratio, w*h*ratio**2))
            by_image[row['id']].append(ann)
            if min(w, h) * 416 / max(row['width'], row['height']) < 2:
                suspicious.append({'split': split, 'image_id': row['id'], 'annotation_id': ann['id'],
                                   'class': cat['name'], 'reason': 'box_short_side_below_2px_at_416'})
        for image_id, annotations in by_image.items():
            for i, a in enumerate(annotations):
                ax, ay, aw, ah = a['bbox']
                for b in annotations[:i]:
                    if a['category_id'] != b['category_id']:
                        continue
                    bx, by, bw, bh = b['bbox']
                    intersection = max(0, min(ax+aw, bx+bw)-max(ax, bx))*max(0, min(ay+ah, by+bh)-max(ay, by))
                    overlap = intersection / max(aw*ah+bw*bh-intersection, 1e-12)
                    if overlap > .95:
                        suspicious.append({'split': split, 'image_id': image_id, 'annotation_id': a['id'],
                                           'other_annotation_id': b['id'], 'class': categories[a['category_id']]['name'],
                                           'bbox_iou': overlap, 'reason': 'same_class_near_duplicate_box'})
        split_rows[split] = {'images': len(rows), 'task_images': dict(Counter(t for r in rows.values() for t in r['tasks'])),
                             'annotated_empty_damage_images': sum('damage' in r['tasks'] and not any(
                                 categories[a['category_id']]['task'] == 'damage' for a in by_image[r['id']]) for r in rows.values())}
    class_results = {}
    for cat in categories.values():
        name = cat['name']
        class_results[name] = {'task': cat['task'], 'annotations': dict(counts[name]),
                              'images': len(images_per_class[name]), 'projected_scale': {}}
        for resolution in (384, 416, 512, 640):
            values = np.asarray(sizes[name, resolution])
            class_results[name]['projected_scale'][str(resolution)] = {
                'short_side_median_px': float(np.median(values[:, 0])),
                'short_side_below_4px_fraction': float(np.mean(values[:, 0] < 4)),
                'short_side_below_8px_fraction': float(np.mean(values[:, 0] < 8)),
                'coco_small_fraction': float(np.mean(values[:, 1] < 32**2)),
            }
    report = {'split_sha256': {s: sha256(data/f'{s}.json') for s in documents},
              'scale_projection': 'Aspect-preserving letterbox / longest side fit, as used by the historical YOLOX baseline; RF-DETR square resize has different per-axis scales.',
              'catalog_sha256': sha256(data/'classes.json'), 'splits': split_rows,
              'classes': class_results, 'review_candidates': suspicious,
              'review_candidate_counts': dict(Counter(r['reason'] for r in suspicious)),
              'limitations': ['Geometry flags do not establish semantic label errors.',
                             'No verified clean/non-vehicle negative set or vehicle/session IDs.',
                             'Historical test set is frozen for comparison; it is not a fresh production holdout.']}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    if previews:
        previews.mkdir(parents=True, exist_ok=True)
        doc = documents['train']
        raw = Path(doc['info']['source_root'])
        chosen = []
        for cat in categories.values():
            if cat['task'] != 'damage':
                continue
            matches = sorted((a for a in doc['annotations'] if a['category_id'] == cat['id']),
                             key=lambda a: a['bbox'][2]*a['bbox'][3])
            chosen.extend((cat, a) for a in matches[:2]+matches[len(matches)//2:len(matches)//2+1])
        rows = {r['id']: r for r in doc['images']}
        sheet = Image.new('RGB', (900, 210*((len(chosen)+2)//3)), 'white')
        draw = ImageDraw.Draw(sheet)
        for index, (cat, ann) in enumerate(chosen):
            row = rows[ann['image_id']]
            with Image.open(raw/row['file_name']) as im:
                im = im.convert('RGB')
            x, y, w, h = ann['bbox']
            padding = max(w, h)*.3+8
            box = (max(0, int(x-padding)), max(0, int(y-padding)), min(im.width, int(x+w+padding)), min(im.height, int(y+h+padding)))
            crop = im.crop(box)
            ImageDraw.Draw(crop).rectangle((x-box[0], y-box[1], x+w-box[0], y+h-box[1]), outline='red', width=2)
            crop.thumbnail((296, 175))
            sx, sy = (index%3)*300, (index//3)*210
            sheet.paste(crop, (sx, sy+25))
            draw.text((sx+3, sy+3), f"{cat['name']} ann={ann['id']}", fill='black')
        sheet.save(previews/'damage-review.jpg')
    print(json.dumps({'splits': split_rows, 'review_candidate_counts': report['review_candidate_counts']}))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=Path('datasets/hitl-coco'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--previews', type=Path)
    args = parser.parse_args()
    audit(args.data, args.output, args.previews)
