"""Torch-free RF-DETR square RGB preprocessing and set-prediction decoding."""
import numpy as np


def preprocess_rfdetr(image, size, antialias=False):
    """Match PIL validation resize, or tensor predict() resize without antialiasing."""
    if antialias:
        from PIL import Image
        resized = np.asarray(image.convert('RGB').resize((size, size), Image.Resampling.BILINEAR), dtype=np.float32)/255.
        normalized = (resized-np.array([.485, .456, .406], np.float32))/np.array([.229, .224, .225], np.float32)
        return np.ascontiguousarray(normalized.transpose(2, 0, 1), dtype=np.float32)
    pixels = np.asarray(image.convert('RGB'))
    sy = (np.arange(size, dtype=np.float32)+.5)*(image.height/size)-.5
    sx = (np.arange(size, dtype=np.float32)+.5)*(image.width/size)-.5
    y, x = np.floor(sy).astype(int), np.floor(sx).astype(int)
    wy, wx = (sy-y).astype(np.float32)[:, None, None], (sx-x).astype(np.float32)[None, :, None]
    y0, y1 = np.clip(y, 0, image.height-1), np.clip(y+1, 0, image.height-1)
    x0, x1 = np.clip(x, 0, image.width-1), np.clip(x+1, 0, image.width-1)
    top = pixels[y0[:, None], x0].astype(np.float32)*(1-wx)+pixels[y0[:, None], x1].astype(np.float32)*wx
    bottom = pixels[y1[:, None], x0].astype(np.float32)*(1-wx)+pixels[y1[:, None], x1].astype(np.float32)*wx
    resized = (top*(1-wy)+bottom*wy)/255.
    normalized = (resized-np.array([.485, .456, .406], np.float32))/np.array([.229, .224, .225], np.float32)
    return np.ascontiguousarray(normalized.transpose(2, 0, 1), dtype=np.float32)


def postprocess_rfdetr(boxes, logits, categories, width, height, threshold=.25, limit=300, background_class=True):
    boxes, logits = np.asarray(boxes)[0], np.asarray(logits)[0]
    if boxes.ndim != 2 or boxes.shape[-1] != 4 or logits.shape != (len(boxes), len(categories)+int(background_class)):
        raise ValueError('RF-DETR output shape differs from the class contract')
    if not np.isfinite(boxes).all() or not np.isfinite(logits).all():
        raise ValueError('Nonfinite RF-DETR output')
    probabilities = 1/(1+np.exp(-np.clip(logits, -80, 80)))
    flattened = probabilities.ravel()
    selected = np.argsort(-flattened, kind='stable')[:limit]
    results = []
    for flat in selected:
        query, label = divmod(int(flat), logits.shape[1])
        confidence = float(flattened[flat])
        if confidence < threshold or (background_class and label == len(categories)):
            continue
        category = categories[label]
        cx, cy, w, h = map(float, boxes[query])
        x1, x2 = np.clip([(cx-w/2)*width, (cx+w/2)*width], 0, width)
        y1, y2 = np.clip([(cy-h/2)*height, (cy+h/2)*height], 0, height)
        if x2 <= x1 or y2 <= y1:
            continue
        results.append({'classId': category['id'], 'code': category['code'], 'task': category['task'],
                        'label': category['name'], 'confidence': confidence,
                        'boundingBox': {'x1': float(x1), 'y1': float(y1), 'x2': float(x2), 'y2': float(y2)},
                        '_query': query})
    # The existing analysis contract permits at most 100 detections per task.
    return results[:100]
