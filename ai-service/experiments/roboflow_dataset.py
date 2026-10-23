"""Independent RF experiment contract; never relaxes the production taxonomy."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

from experiments.config import load_yaml, validate_detection_dataset

ROOT = Path(__file__).resolve().parents[1]
MAPPING = ROOT / 'config/roboflow_damage_v3.yaml'
SPLITS = {'train': 'train', 'val': 'valid', 'test': 'test'}
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp'}


def sha256(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def digest_json(value) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=True,
                                     separators=(',', ':')).encode()).hexdigest()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def mapping(path: Path = MAPPING) -> dict:
    config = load_yaml(path)
    source, target = config['source_names'], config['model_names']
    if (config.get('class_policy') != 'preserve_bijective' or len(source) != 11
            or len(target) != 11 or len(set(source)) != 11 or len(set(target)) != 11
            or any(not isinstance(n, str) or not n or not n.replace('_', '').isalnum()
                   or n != n.upper() for n in target)):
        raise ValueError('First experiment must preserve all 11 classes one-to-one; no merging or dropping.')
    return config


def polygon_box(line: str, nc: int) -> tuple[int, list[float], list[tuple[float, float]]]:
    fields = line.split()
    if len(fields) < 7 or len(fields) % 2 != 1:
        raise ValueError('Expected class plus at least three polygon XY pairs, not a detection row.')
    class_id = int(fields[0])
    if not 0 <= class_id < nc:
        raise ValueError('Class ID outside experimental class range.')
    coords = [float(v) for v in fields[1:]]
    if any(not math.isfinite(v) or not 0 <= v <= 1 for v in coords):
        raise ValueError('Non-finite or out-of-range polygon coordinate; no silent clipping.')
    points = list(zip(coords[::2], coords[1::2]))
    # Repeated closing point is a conventional polygon representation.
    if points[0] == points[-1]:
        points.pop()
    if len(points) < 3 or len(set(points)) != len(points):
        raise ValueError('Degenerate polygon or repeated vertex.')
    array = np.asarray(points, dtype=np.float64)
    area = abs(float(np.dot(array[:, 0], np.roll(array[:, 1], 1))
                     - np.dot(array[:, 1], np.roll(array[:, 0], 1)))) / 2
    if area <= 1e-12:
        raise ValueError('Zero-area polygon.')
    if self_intersects(array):
        raise ValueError('Self-intersecting polygon.')
    x1, y1 = array.min(axis=0)
    x2, y2 = array.max(axis=0)
    if x2 <= x1 or y2 <= y1:
        raise ValueError('Degenerate bounding box.')
    return class_id, [float((x1+x2)/2), float((y1+y2)/2), float(x2-x1), float(y2-y1)], points


def self_intersects(points: np.ndarray) -> bool:
    """Non-adjacent edges may neither cross nor touch (including collinear overlap)."""
    def cross(a, b):
        return a[..., 0] * b[..., 1] - a[..., 1] * b[..., 0]
    n = len(points)
    ends = np.roll(points, -1, axis=0)
    for i in range(n - 2):
        indexes = np.arange(i + 2, n if i else n - 1)
        if not len(indexes):
            continue
        a, b, c, d = points[i], ends[i], points[indexes], ends[indexes]
        o1, o2 = cross(b-a, c-a), cross(b-a, d-a)
        o3, o4 = cross(d-c, a-c), cross(d-c, b-c)
        overlap = np.all(np.maximum(np.minimum(a, b), np.minimum(c, d))
                         <= np.minimum(np.maximum(a, b), np.maximum(c, d)) + 1e-12, axis=1)
        if np.any((o1*o2 <= 0) & (o3*o4 <= 0) & overlap):
            return True
    return False


def image_signature(path: Path) -> dict:
    with Image.open(path) as original:
        if original.width * original.height > 64_000_000:
            raise ValueError('Image exceeds 64 megapixels.')
        if original.getexif().get(274, 1) != 1:
            raise ValueError('Nontrivial EXIF orientation requires annotation-coordinate review.')
        original.load()
        image = original.convert('RGB')
    gray = np.asarray(image.convert('L').resize((32, 32)), dtype=np.float32)
    coefficients = cv2.dct(gray)[:8, :8].flatten()[1:]
    bits = coefficients > np.median(coefficients)
    phash = sum(int(bit) << i for i, bit in enumerate(bits))
    return {'width': image.width, 'height': image.height, 'phash': f'{phash:016x}',
            'pixel_sha256': hashlib.sha256(str(image.size).encode() + image.tobytes()).hexdigest()}


def source_manifest(root: Path) -> list[dict]:
    entries = []
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError(f'Symlinks are not accepted in source: {path}')
        if path.is_file():
            entries.append({'path': path.relative_to(root).as_posix(), 'sha256': sha256(path)})
    return entries


def find_duplicates(records: list[dict], threshold: int = 6) -> list[dict]:
    pairs = []
    for i, left in enumerate(records):
        if 'phash' not in left:
            continue
        for right in records[i+1:]:
            if 'phash' not in right:
                continue
            exact = left['image_sha256'] == right['image_sha256'] or left['pixel_sha256'] == right['pixel_sha256']
            distance = (int(left['phash'], 16) ^ int(right['phash'], 16)).bit_count()
            ratio = (left['width']/left['height']) / (right['width']/right['height'])
            if exact or (distance <= threshold and .90 <= ratio <= 1.10):
                pairs.append({'left': left['key'], 'right': right['key'],
                              'kind': 'exact' if exact else 'near_candidate', 'hamming': distance,
                              'same_label_bytes': left.get('label_sha256') == right.get('label_sha256'),
                              'cross_split': left['split'] != right['split'],
                              'id': digest_json([left['key'], right['key']])[:20]})
    return pairs


def draw_sample(source: Path, output: Path, objects: list, names: list[str]) -> None:
    with Image.open(source) as original:
        image = original.convert('RGB')
    image.thumbnail((1000, 760))
    draw = ImageDraw.Draw(image)
    for class_id, box, points in objects:
        vertices = [(x*image.width, y*image.height) for x, y in points]
        draw.line(vertices + vertices[:1], fill='#00ffff', width=2)
        x, y, w, h = box
        bounds = ((x-w/2)*image.width, (y-h/2)*image.height,
                  (x+w/2)*image.width, (y+h/2)*image.height)
        draw.rectangle(bounds, outline='#ff3030', width=3)
        title = f'{class_id}: {names[class_id]}'
        draw.text((max(0, bounds[0]), max(0, bounds[1]-12)), title,
                  fill='white', stroke_width=2, stroke_fill='black')
    image.save(output)


def validate_experiment(data: Path, *, review: Path | None = None) -> dict:
    """Training/evaluation gate: exact content, explicit taxonomy, and human review."""
    root = data.resolve().parent
    contract = mapping()
    config = load_yaml(data)
    if config.get('names') != contract['model_names'] or config.get('nc') != 11:
        raise ValueError('Not the RF eleven-class experiment; production validation is unchanged.')
    if 'path' in config or any(config.get(s) != f'images/{s}' for s in SPLITS):
        raise ValueError('Experiment splits must be confined to images/train,val,test.')
    validation = validate_detection_dataset(data, config)
    report = json.loads((root/'import-report.json').read_text(encoding='utf-8'))
    if report['mapping_sha256'] != sha256(MAPPING):
        raise ValueError('Mapping changed since import; re-import required.')
    expected = {item['path']: item['sha256'] for item in report['output_manifest']}
    actual_paths = {p.relative_to(root).as_posix() for group in ['images', 'labels']
                    for p in (root/group).rglob('*') if p.is_file() and p.suffix.lower() != '.cache'}
    expected_data = {p for p in expected if p.startswith(('images/', 'labels/'))}
    if actual_paths != expected_data:
        raise ValueError('Dataset membership changed since import.')
    for relative, digest in expected.items():
        path = root / relative
        if path.is_symlink() or not path.resolve().is_relative_to(root) or not path.is_file() or sha256(path) != digest:
            raise ValueError(f'Dataset/review artifact changed: {relative}')
    if review is None:
        return validation
    approval = json.loads(review.read_text(encoding='utf-8'))
    if approval.get('import_report_sha256') != sha256(root/'import-report.json'):
        raise ValueError('Review does not match this exact import report.')
    if not str(approval.get('reviewer', '')).strip() or not approval.get('reviewed_at'):
        raise ValueError('Named and dated visual review is mandatory.')
    for key in ('annotations_accepted', 'quarantine_accepted', 'negative_images_checked', 'imbalance_accepted', 'provenance_reviewed_for_research'):
        if approval.get(key) is not True:
            raise ValueError(f'Review incomplete: {key}')
    if set(approval.get('reviewed_samples', [])) != set(report['review_samples']):
        raise ValueError('Every generated visual sample must be reviewed.')
    retained = {r['key'] for r in report['records'] if r['status'] == 'imported'}
    for pair in report['duplicate_pairs']:
        if not pair['cross_split'] or not {pair['left'], pair['right']}.issubset(retained):
            continue
        if pair['kind'] == 'exact':
            raise ValueError('Exact cross-split leakage blocks training; quarantine whole affected images and re-import.')
        decisions = approval.get('near_duplicate_decisions', {})
        decision = decisions.get(pair['id'], {})
        if decision.get('decision') != 'distinct' or not str(decision.get('reason', '')).strip():
            raise ValueError(f'Unresolved cross-split similarity: {pair["id"]}')
    if any(not validation['images_per_split'][s] for s in SPLITS):
        raise ValueError('Every split must contain images.')
    if any(report['class_counts']['train'].get(n, 0) == 0 for n in contract['model_names']):
        raise ValueError('Every experimental class must have training support.')
    return validation
