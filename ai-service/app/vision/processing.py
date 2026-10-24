from __future__ import annotations

from io import BytesIO
import warnings
import numpy as np
from PIL import Image, ImageFilter, UnidentifiedImageError

MAX_PIXELS = 24_000_000


def decode_image(content):
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(BytesIO(content), formats=('JPEG','PNG','WEBP')) as source:
                if source.width * source.height > MAX_PIXELS:
                    raise ValueError('Fotoğrafın piksel boyutu çok büyük.')
                source.load()
                return source.convert('RGB')
    except (OSError, UnidentifiedImageError, Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise ValueError('Fotoğraf okunamadı; JPG, PNG veya WEBP kullanın.') from exc


def quality(image):
    # Photometric only: this does not claim that a vehicle is present.
    gray = image.convert('L')
    gray.thumbnail((1024,1024))
    a = np.asarray(gray, dtype=np.float32)
    edges = np.asarray(gray.filter(ImageFilter.FIND_EDGES),dtype=np.float32)[1:-1,1:-1]
    suitable = min(image.size) >= 128 and 25 <= float(a.mean()) <= 235 and edges.size > 0 and float(edges.var()) >= 15
    return {'suitable': suitable, 'status': 'SUITABLE' if suitable else 'UNSUITABLE',
            'message': 'Fotoğrafın ışık ve netlik kontrolü tamamlandı.' if suitable else 'Daha net ve yeterli ışıkta bir fotoğraf kullanın.'}


def preprocess(image, size):
    ratio = min(size/image.width, size/image.height)
    resized = image.resize((max(1,int(image.width*ratio)), max(1,int(image.height*ratio))), Image.Resampling.BILINEAR)
    canvas = np.full((size,size,3),114,dtype=np.float32)
    canvas[:resized.height,:resized.width] = np.asarray(resized)[:,:,::-1]
    return np.ascontiguousarray(canvas.transpose(2,0,1)), ratio


def iou(a,b):
    left = np.maximum(a[:2],b[:2]); right = np.minimum(a[2:],b[2:])
    intersection = float(np.maximum(right-left,0).prod())
    area_a = float(np.maximum(a[2:]-a[:2],0).prod())
    area_b = float(np.maximum(b[2:]-b[:2],0).prod())
    return intersection/max(area_a+area_b-intersection,1e-9)


def postprocess(predictions, categories, ratio, width, height, threshold=.25, nms=.45):
    p = np.asarray(predictions)[0]
    if p.ndim != 2 or p.shape[1] != 5+len(categories) or not np.isfinite(p).all():
        raise ValueError(f'Invalid detection head output: shape={p.shape}, finite={np.isfinite(p).all()}')
    scores = p[:,4:5] * p[:,5:]
    rows, classes = np.where(scores >= threshold)
    candidates = []
    for row, cls in zip(rows,classes):
        center, extent = p[row,:2], p[row,2:4]
        box = np.r_[center-extent/2,center+extent/2]/ratio
        box[[0,2]] = np.clip(box[[0,2]],0,width)
        box[[1,3]] = np.clip(box[[1,3]],0,height)
        if box[2] <= box[0] or box[3] <= box[1]:
            continue
        category = categories[cls]
        candidates.append({'classId': category['id'], 'label': category['name'], 'code': category['code'],
            'task': category['task'], 'confidence': float(scores[row,cls]),
            'boundingBox': dict(zip(('x1','y1','x2','y2'),map(float,box)))})
    kept = []
    for item in sorted(candidates,key=lambda x:x['confidence'],reverse=True)[:1000]:
        box = np.array(list(item['boundingBox'].values()))
        if not any(x['classId']==item['classId'] and iou(box,np.array(list(x['boundingBox'].values())))>nms for x in kept):
            kept.append(item)
        if len(kept) >= 100:
            break
    return kept


def match_parts(damage, parts, vehicle_region=None):
    box = np.array(list(damage['boundingBox'].values()))
    area = float((box[2]-box[0])*(box[3]-box[1]))
    matches = []
    for part in parts:
        p = np.array(list(part['boundingBox'].values()))
        overlap = float(np.maximum(np.minimum(box[2:],p[2:])-np.maximum(box[:2],p[:2]),0).prod())/max(area,1e-9)
        if vehicle_region == 'FRONT' and part['code'].startswith('BACK_'):
            continue
        if vehicle_region == 'REAR' and part['code'].startswith('FRONT_'):
            continue
        if overlap >= .25 and part['confidence'] >= .4:
            matches.append((overlap,part))
    matches.sort(key=lambda x:x[0],reverse=True)
    # Ambiguous overlapping anatomy remains unknown, never force BACK from FRONT/REAR.
    if not matches:
        return []
    if len(matches)>1:
        a=np.array(list(matches[0][1]['boundingBox'].values()))
        b=np.array(list(matches[1][1]['boundingBox'].values()))
        if iou(a,b)<.1 and matches[0][0]+matches[1][0]>=.8:
            return list(dict.fromkeys(m[1]['code'] for m in matches[:2]))
        if abs(matches[0][0]-matches[1][0])<.1:
            return []
    if matches[0][0]<.6:
        return []
    return [matches[0][1]['code']]
