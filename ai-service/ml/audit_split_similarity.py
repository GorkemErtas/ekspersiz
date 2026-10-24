"""Read-only cross-split perceptual similarity review; does not relabel or move images."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageOps
from scipy.fft import dctn


def signature(image):
    gray = image.convert('L')
    small = np.asarray(gray.resize((32, 32), Image.Resampling.LANCZOS), dtype=np.float32)
    coefficients = dctn(small, type=2, norm='ortho')[:8, :8].ravel()[1:]
    median = np.median(coefficients)
    phash = sum(int(value > median) << i for i, value in enumerate(coefficients))
    diff = np.asarray(gray.resize((9, 8), Image.Resampling.LANCZOS), dtype=np.float32)
    dhash = sum(int(value) << i for i, value in enumerate((diff[:, 1:] > diff[:, :-1]).ravel()))
    return phash, dhash, float(small.std())


def audit(data, output, preview):
    records, hashes = [], {}
    for split in ('train', 'val', 'test'):
        path = data/f'{split}.json'
        document = json.loads(path.read_text(encoding='utf-8'))
        hashes[split] = hashlib.sha256(path.read_bytes()).hexdigest()
        root = Path(document['info']['source_root'])
        for row in document['images']:
            source = root/row['file_name']
            with Image.open(source) as image:
                phash, dhash, std = signature(image)
                exif_orientation = image.getexif().get(274)
            records.append({'split': split, 'id': row['id'], 'file_name': row['file_name'],
                            'group_id': row['group_id'], 'path': source, 'width': row['width'],
                            'height': row['height'], 'phash': phash, 'dhash': dhash, 'std': std,
                            'exif_orientation': exif_orientation})
    pairs = []
    for i, a in enumerate(records):
        for b in records[:i]:
            if a['split'] == b['split'] or min(a['std'], b['std']) < 5:
                continue
            if abs((a['width']/a['height'])/(b['width']/b['height'])-1) > .05:
                continue
            p_distance = (a['phash'] ^ b['phash']).bit_count()
            if p_distance > 4:
                continue
            d_distance = (a['dhash'] ^ b['dhash']).bit_count()
            if d_distance > 8:
                continue
            pairs.append({'a': {k:a[k] for k in ('split','id','file_name','group_id')},
                          'b': {k:b[k] for k in ('split','id','file_name','group_id')},
                          'phash_hamming': p_distance, 'dhash_hamming': d_distance})
    pairs.sort(key=lambda row: (not any(row[key]['split'] == 'test' for key in ('a','b')),
                               row['phash_hamming'], row['dhash_hamming']))
    counts = {}
    for pair in pairs:
        key = '-'.join(sorted((pair['a']['split'], pair['b']['split'])))
        counts[key] = counts.get(key, 0)+1
    report = {'split_sha256': hashes, 'images_checked': len(records),
              'method': '63-bit 8x8 low-frequency DCT pHash + 64-bit horizontal dHash; 32x32 grayscale',
              'candidate_rules': {'maximum_phash_hamming':4, 'maximum_dhash_hamming':8,
                                  'maximum_relative_aspect_difference':.05, 'minimum_grayscale_std':5},
              'candidate_pairs': pairs, 'candidate_counts': counts,
              'nontrivial_exif_orientations': [{k:row[k] for k in ('split','id','exif_orientation')}
                                             for row in records if row['exif_orientation'] not in (None,1)],
              'raw_files_changed': False, 'splits_changed':False,
              'limitations': ['Similarity is a review flag, not proof of identical photographs or shared vehicles.',
                              'Crops, viewpoint changes and substantial edits may evade these hashes.',
                              'This post-evaluation source audit does not create a new blind acceptance holdout.']}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    if pairs:
        selected = pairs[:12]
        sheet = Image.new('RGB', (800, 220*len(selected)), 'white')
        draw = ImageDraw.Draw(sheet)
        by_id = {(r['split'],r['id']):r for r in records}
        for i, pair in enumerate(selected):
            for j, key in enumerate(('a','b')):
                row = by_id[pair[key]['split'], pair[key]['id']]
                with Image.open(row['path']) as source:
                    image = ImageOps.contain(source.convert('RGB'), (390,185))
                sheet.paste(image, (j*400,i*220+24))
                draw.text((j*400+4,i*220+4), f'{row["split"]} id={row["id"]} p={pair["phash_hamming"]} d={pair["dhash_hamming"]}', fill='black')
        preview.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(preview)
    print(json.dumps({'images_checked':len(records), 'candidate_counts':counts, 'exif_rotations':len(report['nontrivial_exif_orientations'])}))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=Path('datasets/hitl-coco'))
    parser.add_argument('--output', type=Path, default=Path('../docs/ml/TRANSFER_SPLIT_SIMILARITY.json'))
    parser.add_argument('--preview', type=Path, default=Path('evaluation-runs/split-similarity/preview.jpg'))
    args = parser.parse_args()
    audit(args.data, args.output, args.preview)
