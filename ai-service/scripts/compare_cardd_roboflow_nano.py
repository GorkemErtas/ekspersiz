"""Read-only dataset audit and exploratory paired YOLO11n comparison.

Run audit first, then evaluate. All generated files stay in --output. No training,
dataset rewrite, checkpoint rewrite or production evaluator import occurs.
"""
from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import cv2
import numpy as np
from PIL import Image, ImageDraw
import yaml
from experiments.damage_comparison import (COMMON, NAMES, common_objects, eligible,
    family, contaminated_components, evaluate)
from experiments.roboflow_dataset import image_signature, sha256, validate_experiment

DATA = {'cardd': ROOT/'datasets/vehicle_damage_detection_v2',
        'roboflow': ROOT/'datasets/vehicle_damage_detection_v3_rf_reviewed'}
WEIGHTS = {'cardd': ROOT/'models/candidates/damage_detection_v2_cardd_5class.pt',
           'roboflow': ROOT/'training-runs/roboflow-v3/rf11-n-seed42/weights/best.pt'}
SETTINGS = dict(imgsz=640, conf=.001, iou=.60, max_det=300, batch=1,
                rect=False, half=False, augment=False, agnostic_nms=False,
                verbose=False, save=False)


def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False), encoding='utf-8')


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def labels(path, names):
    if not path.is_file():
        raise ValueError(f'Missing annotation (not a negative): {path}')
    objects = []
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        if not line.strip():
            continue
        values = np.array(list(map(float, line.split())))
        if len(values) != 5 or not np.isfinite(values).all():
            raise ValueError(f'Invalid bbox: {path}')
        c, x, y, w, h = values
        if c != int(c) or not 0 <= c < len(names) or min(w, h) <= 0:
            raise ValueError(f'Invalid class or size: {path}')
        box = [x-w/2, y-h/2, x+w/2, y+h/2]
        if min(box) < -1e-5 or max(box) > 1+1e-5:
            raise ValueError(f'Out of bounds bbox: {path}')
        objects.append(dict(cls=int(c), box=box))
    return objects


def inventory():
    validate_experiment(DATA['roboflow']/'data.yaml', review=DATA['roboflow']/'review.json')
    records = []
    for source, directory in DATA.items():
        config = yaml.safe_load((directory/'data.yaml').read_text())
        names = config['names']
        names = tuple(names[i] for i in range(len(names))) if isinstance(names, dict) else tuple(names)
        if names != NAMES[source]:
            raise ValueError('Unexpected dataset class contract')
        for split in ('train', 'val', 'test'):
            for image in sorted((directory/config[split]).rglob('*')):
                if image.suffix.lower() not in {'.jpg', '.jpeg', '.png', '.webp'}:
                    continue
                relative = image.relative_to(directory/'images')
                label = (directory/'labels'/relative).with_suffix('.txt')
                gt = labels(label, names)
                record = dict(id=f'{source}/{relative.as_posix()}', source=source, split=split,
                              image=str(image), label=str(label), gt=gt, hidden_tire=False,
                              image_sha256=sha256(image), label_sha256=sha256(label),
                              family=family(image.stem))
                if source == 'cardd':
                    raw = ROOT/'datasets/raw/cardd'/split/'labels'/label.name
                    original = labels(raw, range(6))
                    record.update(raw_label=str(raw), raw_label_sha256=sha256(raw),
                                  hidden_tire=any(o['cls'] == 5 for o in original))
                records.append(record)
    return records


def descriptor(record):
    sig = image_signature(Path(record['image']))
    with Image.open(record['image']) as image:
        small = np.asarray(image.convert('RGB').resize((24, 24)), dtype=np.float32)/255
    # Lightweight retrieval only, not proof of distinct vehicles/scenes.
    gray = cv2.cvtColor(small, cv2.COLOR_RGB2GRAY).flatten()
    gray -= gray.mean()
    gray /= max(np.linalg.norm(gray), 1e-8)
    return sig, gray


def sift_features(record):
    image = cv2.imread(record['image'], cv2.IMREAD_GRAYSCALE)
    h, w = image.shape
    image = cv2.resize(image, (round(w*min(1, 512/max(w,h))), round(h*min(1, 512/max(w,h)))))
    keypoints, descriptors = cv2.SIFT_create(nfeatures=600).detectAndCompute(image, None)
    points = np.array([p.pt for p in keypoints], dtype=np.float32)
    return points, descriptors, image.shape


def scene_match(left, right):
    lp, ld, ls = left
    rp, rd, rs = right
    if ld is None or rd is None or min(len(ld), len(rd)) < 12:
        return None
    pairs = cv2.BFMatcher().knnMatch(ld, rd, k=2)
    good = [a for pair in pairs if len(pair) == 2 for a, b in [pair] if a.distance < .70*b.distance]
    if len(good) < 14:
        return None
    a = np.float32([lp[m.queryIdx] for m in good])
    b = np.float32([rp[m.trainIdx] for m in good])
    _, mask = cv2.findHomography(a, b, cv2.RANSAC, 3.)
    if mask is None:
        return None
    mask = mask.ravel().astype(bool)
    inliers = int(mask.sum())
    if inliers < 14:
        return None
    coverage = min(cv2.contourArea(cv2.convexHull(points[mask]))/(shape[0]*shape[1])
                   for points, shape in ((a, ls), (b, rs)))
    if inliers >= 14 and inliers/len(good) >= .5 and coverage >= .04:
        return dict(inliers=inliers, good_matches=len(good), coverage=float(coverage))
    return None


def contact_sheet(records, pairs, path):
    canvas = Image.new('RGB', (1000, 210*len(pairs)), 'white')
    draw = ImageDraw.Draw(canvas)
    for row, pair in enumerate(pairs):
        for column, index in enumerate(pair):
            record = records[index]
            with Image.open(record['image']) as original:
                image = original.convert('RGB')
            image.thumbnail((480, 170))
            canvas.paste(image, (column*500, row*210+32))
            draw.text((column*500+2, row*210), record['id'][:77], fill='black')
    canvas.save(path)


def audit(output):
    if (output/'audit.json').exists():
        raise ValueError('Audit exists; use a new output directory to recompute.')
    records = inventory()
    print(f'Inventory: {len(records)} images; computing signatures', flush=True)
    vectors = []
    with ThreadPoolExecutor(max_workers=4) as pool:
        for record, (sig, vector) in zip(records, pool.map(descriptor, records)):
            record.update(sig)
            vectors.append(vector)
    vectors = np.array(vectors)
    hashes = [int(r['phash'], 16) for r in records]
    tests = [i for i, r in enumerate(records) if r['split'] == 'test']
    edges, seen, retrieval = [], set(), []
    def add(i, j, kind, **details):
        key = tuple(sorted((i, j)))
        if i != j and key not in seen:
            seen.add(key)
            edges.append(dict(left=i, right=j, kind=kind, **details))
    # Exhaustive test-to-all exact/pHash/family comparison (both training sources).
    for i in tests:
        distances = np.array([(hashes[i]^h).bit_count() for h in hashes])
        distances[i] = 100
        similarities = vectors @ vectors[i]
        similarities[i] = -10
        candidates = set(np.argsort(distances, kind='stable')[:12].tolist())
        candidates.update(np.argsort(-similarities, kind='stable')[:12].tolist())
        for j, r in enumerate(records):
            if i == j:
                continue
            a = records[i]
            if a['image_sha256'] == r['image_sha256'] or a['pixel_sha256'] == r['pixel_sha256']:
                add(i,j,'exact')
            elif a['family'] == r['family']:
                add(i,j,'source_filename_family')
            elif distances[j] <= 10:
                # Conservative: no aspect-ratio filter; crops may change it.
                add(i,j,'perceptual_suspect', hamming=int(distances[j]))
            if a['family'].isdigit() and r['family'].isdigit() and len(a['family']) == 6 and len(r['family']) == 6:
                if abs(int(a['family'])-int(r['family'])) <= 4:
                    candidates.add(j)
        retrieval.append((i, sorted(candidates)))
    print(f'Exact/perceptual/family edges: {len(edges)}; local feature scene screening', flush=True)
    feature_cache = {}
    for k, (i, candidates) in enumerate(retrieval):
        for j in candidates:
            if tuple(sorted((i,j))) in seen:
                continue
            for index in (i,j):
                if index not in feature_cache:
                    feature_cache[index] = sift_features(records[index])
            details = scene_match(feature_cache[i], feature_cache[j])
            if details:
                add(i,j,'local_feature_scene_suspect', **details)
        if k % 50 == 0:
            print(f'Scene retrieval {k}/{len(tests)}', flush=True)
    roots, contaminated = contaminated_components(records, edges)
    retained, representative = [], {}
    for i in tests:
        r = records[i]
        reasons = []
        if i in contaminated:
            reasons.append('connected_to_either_model_train_or_val')
        if roots[i] in representative:
            reasons.append('test_component_duplicate')
        else:
            representative[roots[i]] = i
        r['common_eligible'] = eligible(r)
        r['leakage_excluded'] = i in contaminated
        r['component'] = roots[i]
        r['deduplicated_test'] = not reasons
        r['exclusion_reasons'] = reasons + ([] if eligible(r) else ['noncommon_damage_or_unverified_negative'])
        if not r['exclusion_reasons']:
            retained.append(i)
    summary = dict(total_images=len(records), splits=dict(Counter(f"{r['source']}/{r['split']}" for r in records)),
                   candidate_test_images=len(tests), leakage_excluded=len(contaminated),
                   edge_counts=dict(Counter(e['kind'] for e in edges)),
                   common_test_images=len(retained), common_sources=dict(Counter(records[i]['source'] for i in retained)),
                   common_instances=dict(Counter(COMMON[o['cls']] for i in retained
                                                for o in common_objects(records[i]['source'], records[i]['gt']))))
    provenance = {str(p.relative_to(ROOT)): sha256(p) for p in [
        DATA['cardd']/'data.yaml', DATA['cardd']/'cardd-import-report.json',
        DATA['roboflow']/'data.yaml', DATA['roboflow']/'import-report.json', DATA['roboflow']/'review.json',
        ROOT/'config/cardd_import.yaml', ROOT/'config/roboflow_damage_v3.yaml',
        ROOT/'training-runs/roboflow-v3/rf11-n-seed42/experiment.json']}
    result = dict(records=records, edges=edges, common_indices=retained, summary=summary,
                  metadata_hashes=provenance, scene_retrieval=retrieval,
                  method='SHA256 bytes/RGB; 63-bit pHash <=10; filename family; SIFT RANSAC on top12 pHash + top12 grayscale + nearby numeric IDs',
                  limitations=['No vehicle IDs or exhaustive scene labels; retrieval can miss different views/crops.',
                               'CarDD training-time dataset manifest unavailable; current data matches checkpoint data path, not proven historical membership.',
                               'Common annotation meaning/exhaustiveness not independently adjudicated across all test images.'])
    write(output/'audit.json', result)
    for kind in ('exact','perceptual_suspect','local_feature_scene_suspect','source_filename_family'):
        pairs = [(e['left'], e['right']) for e in edges if e['kind']==kind][:8]
        if pairs:
            contact_sheet(records, pairs, output/f'audit_{kind}.jpg')
    # All retained test candidates, with nearest training/validation visual neighbor,
    # for optional human review; this is not marked as reviewed automatically.
    for offset in range(0, len(retained), 8):
        pairs = []
        for i in retained[offset:offset+8]:
            candidates = [j for j in range(len(records)) if records[j]['split'] != 'test']
            j = max(candidates, key=lambda j: float(vectors[i] @ vectors[j]))
            pairs.append((i,j))
        contact_sheet(records, pairs, output/f'review_neighbors_{offset//8:03}.jpg')
    print(json.dumps(summary), flush=True)


def verify(audit_data):
    for relative, expected in audit_data['metadata_hashes'].items():
        if sha256(ROOT/relative) != expected:
            raise ValueError(f'Metadata changed after audit: {relative}')
    for record in audit_data['records']:
        for key in ('image','label','raw_label'):
            if key in record and sha256(Path(record[key])) != record[key+'_sha256']:
                raise ValueError(f'Input changed after audit: {record[key]}')


def review_sheets(output):
    data=read(output/'audit.json')
    indices=data['common_indices']
    for offset in range(0,len(indices),12):
        canvas=Image.new('RGB',(1200,900),'white')
        draw=ImageDraw.Draw(canvas)
        for slot,i in enumerate(indices[offset:offset+12]):
            r=data['records'][i]
            x,y=(slot%4)*300,(slot//4)*300
            with Image.open(r['image']) as original: image=original.convert('RGB')
            image.thumbnail((295,250))
            canvas.paste(image,(x,y+45))
            draw.text((x+2,y+2),f"index {i} | {r['source']} | {Path(r['image']).name[:28]}",fill='black')
            draw.text((x+2,y+18),','.join(sorted({NAMES[r['source']][o['cls']] for o in r['gt']})),fill='black')
        canvas.save(output/f'common_review_{offset//12:02}.jpg',quality=92)


def reviewed_cohort(output):
    data=read(output/'audit.json')
    review=read(output/'cohort_review.json')
    if review['audit_sha256'] != sha256(output/'audit.json'):
        raise ValueError('Stale visual review')
    decisions=review['decisions']
    for i in data['common_indices']:
        decision=decisions.get(str(i))
        if (not decision or decision['decision'] not in ('retain_exploratory','exclude') or not decision['reason']
            or decision.get('image') != data['records'][i]['id']):
            raise ValueError(f'Missing explicit review decision for {i}')
        if decision['decision']=='exclude':
            # Also exclude from native diagnostics; no hidden unknown damage.
            data['records'][i]['deduplicated_test']=False
            data['records'][i]['exclusion_reasons'].append('visual_review: '+decision['reason'])
    data['common_indices']=[i for i in data['common_indices'] if decisions[str(i)]['decision']=='retain_exploratory']
    summary=data['summary']
    summary['before_visual_review_common_images']=summary['common_test_images']
    summary['visual_review_excluded']=summary['common_test_images']-len(data['common_indices'])
    summary['common_test_images']=len(data['common_indices'])
    summary['common_sources']=dict(Counter(data['records'][i]['source'] for i in data['common_indices']))
    summary['common_instances']=dict(Counter(COMMON[o['cls']] for i in data['common_indices']
        for o in common_objects(data['records'][i]['source'],data['records'][i]['gt'])))
    data['visual_review']=review
    write(output/'cohort.json',data)
    return data


def load_model(source):
    from ultralytics import YOLO
    model = YOLO(str(WEIGHTS[source]), task='detect')
    if model.names != dict(enumerate(NAMES[source])) or model.model.yaml.get('scale') != 'n':
        raise ValueError('Unexpected checkpoint head or scale')
    if Path(model.ckpt['train_args']['data']).resolve() != (DATA[source]/'data.yaml').resolve():
        raise ValueError('Checkpoint uses a different dataset; extend the exposure audit first')
    if source == 'roboflow':
        experiment = read(ROOT/'training-runs/roboflow-v3/rf11-n-seed42/experiment.json')
        if (sha256(WEIGHTS[source]) != experiment['outputs']['weights/best.pt'] or
            sha256(DATA[source]/'import-report.json') != experiment['dataset_report_sha256'] or
            sha256(DATA[source]/'review.json') != experiment['review_sha256']):
            raise ValueError('RF training provenance mismatch')
    return model


def predict(model, record, device):
    result = model.predict(record['image'], device=device, **SETTINGS)[0]
    boxes = result.boxes
    return [dict(cls=int(c), conf=float(s), box=list(map(float,b))) for c,s,b in
            zip(boxes.cls.cpu().tolist(), boxes.conf.cpu().tolist(), boxes.xyxyn.cpu().tolist())]


def run_evaluation(output, device):
    import torch
    data = reviewed_cohort(output)
    verify(data)
    records = data['records']
    indices = [i for i,r in enumerate(records) if r['split']=='test' and r['deduplicated_test']]
    all_predictions, metrics, native = {}, {}, {}
    for source in WEIGHTS:
        model = load_model(source)
        predictions = {}
        for k,i in enumerate(indices):
            predictions[str(i)] = predict(model, records[i], device)
            if k%50 == 0:
                print(f'{source} predictions {k}/{len(indices)}', flush=True)
        all_predictions[source] = predictions
        items = []
        for i in data['common_indices']:
            pred = predictions[str(i)]
            items.append(dict(id=records[i]['id'], source=records[i]['source'],
                gt=common_objects(records[i]['source'], records[i]['gt']),
                pred=common_objects(source, pred),
                other_pred=[p for p in pred if NAMES[source][p['cls']] not in COMMON]))
        metrics[source] = {'pooled': evaluate(items),
                           'by_source': {s: evaluate([x for x in items if x['source']==s]) for s in DATA},
                           'at_ap_floor': evaluate(items, operating=.001)}
        # Full native taxonomy on own source only, never directly comparable mAP.
        own = [dict(id=records[i]['id'], gt=records[i]['gt'], pred=predictions[str(i)])
               for i in indices if records[i]['source']==source and not records[i]['hidden_tire'] and records[i]['gt']]
        native[source] = evaluate(own, NAMES[source])
        del model
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
    write(output/'predictions.json', all_predictions)
    provenance = dict(checkpoints={s:dict(path=str(p),sha256=sha256(p),bytes=p.stat().st_size) for s,p in WEIGHTS.items()},
        scripts={p.name:sha256(p) for p in [Path(__file__),ROOT/'experiments/damage_comparison.py',
                                         ROOT/'experiments/damage_comparison_report.py']},
        audit_sha256=sha256(output/'audit.json'), cohort_sha256=sha256(output/'cohort.json'),
        visual_review_sha256=sha256(output/'cohort_review.json'), settings=dict(SETTINGS,device=device),
        packages={p:importlib.metadata.version(p) for p in ('torch','ultralytics','numpy','Pillow','opencv-python','psutil')},
        python=sys.version, platform=platform.platform(), cpu=platform.processor(),
        cuda=torch.version.cuda, gpu=torch.cuda.get_device_name(0) if torch.cuda.is_available() else None,
        git_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        created_at=datetime.now(timezone.utc).isoformat())
    write(output/'metrics.json', dict(provenance=provenance,common=metrics,native_diagnostics=native))
    verify(data)


def benchmark_worker(output, source, device, repeats, threads):
    import psutil
    import threading
    import torch
    torch.set_num_threads(threads)
    data = read(output/'cohort.json')
    # Fixed input list/order shared by both models, predecoded before timing.
    indices = data['common_indices'][:min(24,len(data['common_indices']))]
    if not indices:
        indices = [i for i,r in enumerate(data['records']) if r['split']=='test'][:24]
    images = [cv2.imread(data['records'][i]['image']) for i in indices]
    process = psutil.Process()
    baseline = process.memory_info().rss
    peak = [baseline]
    stop = threading.Event()
    def sample():
        while not stop.wait(.005):
            peak[0] = max(peak[0], process.memory_info().rss)
    monitor = threading.Thread(target=sample, daemon=True)
    monitor.start()
    model = load_model(source)
    settings = dict(SETTINGS,conf=.25,device=device)
    # AutoBackend overrides threads on first construction. Set the requested
    # count afterwards so all timed runs really use the same thread limit.
    model.predict(images[0], **settings)
    torch.set_num_threads(threads)
    warmup = 10
    for k in range(warmup):
        model.predict(images[k%len(images)], **settings)
    wall, forward = [], []
    for k in range(repeats):
        if device != 'cpu': torch.cuda.synchronize()
        started = time.perf_counter()
        result = model.predict(images[k%len(images)], **settings)[0]
        if device != 'cpu': torch.cuda.synchronize()
        wall.append((time.perf_counter()-started)*1000)
        forward.append(result.speed['inference'])
    stop.set()
    monitor.join()
    memory = process.memory_info()
    result = dict(source=source, device=device, repeats=repeats, warmup=warmup, threads=torch.get_num_threads(),
        image_indices=indices, batch=1, imgsz=640, half=False, conf=.25, nms_iou=.60, max_det=300,
        wall_ms=dict(p50=float(np.percentile(wall,50)),p95=float(np.percentile(wall,95)),samples=wall),
        forward_ms=dict(p50=float(np.percentile(forward,50)),p95=float(np.percentile(forward,95)),samples=forward),
        baseline_rss_bytes=baseline, sampled_peak_rss_bytes=peak[0],
        os_peak_working_set_bytes=getattr(memory,'peak_wset',None),
        cpu=platform.processor(), platform=platform.platform(), logical_cpus=os.cpu_count(),
        gpu=torch.cuda.get_device_name(0) if device != 'cpu' else None,
        checkpoint_sha256=sha256(WEIGHTS[source]), cohort_sha256=sha256(output/'cohort.json'),
        script_sha256=sha256(Path(__file__)), created_at=datetime.now(timezone.utc).isoformat(),
        scope='Local machine only, NOT Railway. Wall: predecoded BGR input + preprocess + forward + NMS + Python API, no disk/network/backend.',
        ram_scope='Fresh child process; total RSS including Python/framework/model, 5ms sampling plus OS lifetime peak on Windows.')
    write(output/f'benchmark_{source}_{device}.json',result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('audit','review-sheets','evaluate','benchmark','benchmark-worker','report','verify'))
    parser.add_argument('--output',type=Path,default=ROOT/'evaluation-runs/cardd-vs-roboflow-nano')
    parser.add_argument('--device',default='0')
    parser.add_argument('--source',choices=tuple(WEIGHTS),default='cardd')
    parser.add_argument('--repeats',type=int,default=120)
    parser.add_argument('--threads',type=int,default=4)
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    if args.phase=='audit': audit(args.output)
    elif args.phase=='review-sheets': review_sheets(args.output)
    elif args.phase=='evaluate': run_evaluation(args.output,args.device)
    elif args.phase=='verify':
        verify(read(args.output/'audit.json'))
        print('All inventoried datasets/labels/metadata unchanged')
    elif args.phase=='benchmark-worker':
        benchmark_worker(args.output,args.source,args.device,args.repeats,args.threads)
    elif args.phase=='benchmark':
        import torch
        for device in ['cpu']+(['0'] if torch.cuda.is_available() else []):
            for source in WEIGHTS:
                subprocess.run([sys.executable,str(Path(__file__)), 'benchmark-worker','--output',str(args.output),
                    '--source',source,'--device',device,'--repeats',str(args.repeats),'--threads',str(args.threads)],check=True)
    elif args.phase=='report':
        from experiments.damage_comparison_report import build_report
        build_report(args.output)


if __name__=='__main__':
    main()
