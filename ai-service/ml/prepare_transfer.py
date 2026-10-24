"""Task-specific COCO views with frozen splits; never expose test images to training."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
import os
from pathlib import Path
import random
import shutil


def prepare(data, output, task='damage', repeat_threshold=0., seed=2026):
    from pycocotools import mask as mask_utils
    if output.exists():
        raise ValueError('Use a new output directory; existing datasets are immutable')
    if task not in ('damage', 'part') or not 0 <= repeat_threshold <= 1:
        raise ValueError('Invalid task/repeat threshold')
    documents = {s: json.loads((data/f'{s}.json').read_text(encoding='utf-8')) for s in ('train', 'val', 'test')}
    groups = [{r['group_id'] for r in doc['images']} for doc in documents.values()]
    if any(groups[i] & groups[j] for i in range(3) for j in range(i)):
        raise ValueError('Cross-split group leakage')
    cats = sorted((c for c in documents['train']['categories'] if c['task'] == task), key=lambda c: c['task_index'])
    ids = {c['id']: c['task_index'] for c in cats}
    categories = [{'id': c['task_index'], 'name': c['name'], 'supercategory': task} for c in cats]
    manifest = {'task': task, 'seed': seed, 'repeat_threshold': repeat_threshold,
                'original_to_task_id': ids, 'source_split_sha256': {s: hashlib.sha256((data/f'{s}.json').read_bytes()).hexdigest() for s in documents},
                'test_exposed_to_training': False, 'splits': {}}
    rng = random.Random(seed)
    for split, destination in (('train', 'train'), ('val', 'valid')):
        doc = documents[split]
        rows = [r for r in doc['images'] if task in r['tasks']]
        by_image = defaultdict(list)
        for a in doc['annotations']:
            if a['category_id'] in ids:
                by_image[a['image_id']].append(a)
        freq = Counter(c for r in rows for c in {a['category_id'] for a in by_image[r['id']]})
        destination_dir = output/destination
        destination_dir.mkdir(parents=True)
        images, annotations = [], []
        repeat_histogram = Counter()
        for row in rows:
            factor = max([1.] + [min(3., math.sqrt(repeat_threshold*len(rows)/freq[c]))
                                for c in {a['category_id'] for a in by_image[row['id']]}]) if split == 'train' else 1.
            repeats = math.floor(factor) + int(rng.random() < factor-math.floor(factor))
            repeat_histogram[repeats] += 1
            for repeat in range(repeats):
                image_id = len(images)+1
                source = Path(doc['info']['source_root'])/row['file_name']
                filename = f"{row['id']}_{repeat}{source.suffix.lower()}"
                try:
                    os.link(source, destination_dir/filename)
                except OSError:
                    shutil.copyfile(source, destination_dir/filename)
                images.append({'id': image_id, 'file_name': filename, 'width': row['width'], 'height': row['height'],
                               'source_image_id': row['id'], 'group_id': row['group_id']})
                for annotation in by_image[row['id']]:
                    a = dict(annotation, id=len(annotations)+1, image_id=image_id,
                             category_id=ids[annotation['category_id']])
                    seg = a['segmentation']
                    if isinstance(seg, dict) and isinstance(seg['counts'], list):
                        seg = mask_utils.frPyObjects(seg, row['height'], row['width'])
                        seg['counts'] = seg['counts'].decode('ascii')
                        a['segmentation'] = seg
                    annotations.append(a)
        document = {'info': {'source': 'HITL CC0, frozen canonical split', 'split': split},
                    'images': images, 'annotations': annotations, 'categories': categories}
        (destination_dir/'_annotations.coco.json').write_text(json.dumps(document, ensure_ascii=False), encoding='utf-8')
        manifest['splits'][split] = {'original_images': len(rows), 'training_view_images': len(images),
                                    'annotations': len(annotations), 'repeat_histogram': dict(repeat_histogram)}
    (output/'provenance.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(manifest))
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=Path('datasets/hitl-coco'))
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--task', choices=('damage', 'part'), default='damage')
    parser.add_argument('--repeat-threshold', type=float, default=0.)
    args = parser.parse_args()
    prepare(args.data, args.output, args.task, args.repeat_threshold)
