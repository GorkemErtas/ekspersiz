"""Evaluate transfer checkpoints on the unchanged canonical split and common metrics."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import time

import numpy as np
from PIL import Image

from app.vision.rfdetr_processing import preprocess_rfdetr, postprocess_rfdetr
from .metrics import score, calibrate


def evaluate(checkpoint, data, output, device='cuda', size=None, threshold=.25, masks=False, antialias=True):
    os.environ['NO_ALBUMENTATIONS_UPDATE'] = '1'
    import torch
    from rfdetr import RFDETR
    os.environ.setdefault('HF_HUB_OFFLINE', '1')
    torch.set_num_threads(4)
    model = RFDETR.from_checkpoint(str(checkpoint), device=device, trust_checkpoint=False)
    network = model.model.model.to(device).eval()
    size = size or model.model_config.resolution
    document = json.loads(data.read_text(encoding='utf-8'))
    # External data may cover only shared classes; the trained head still has all eight.
    canonical = json.loads((Path(__file__).resolve().parents[1]/'app/vision/classes.json').read_text(encoding='utf-8'))
    categories = sorted((c for c in canonical['categories'] if c['task'] == 'damage'), key=lambda c: c['task_index'])
    if model.model_config.num_classes != len(categories):
        raise ValueError('Checkpoint class count differs from the application contract')
    if any(c not in canonical['categories'] for c in document['categories']):
        raise ValueError('Evaluation class identity differs from the application catalog')
    predictions, mask_predictions, timings = [], [], []
    root = Path(document['info']['source_root'])
    with torch.inference_mode():
        for row in document['images']:
            if 'damage' not in row['tasks']:
                continue
            with Image.open(root/row['file_name']) as source:
                image = source.convert('RGB')
            tensor = torch.from_numpy(preprocess_rfdetr(image, size, antialias)[None]).to(device)
            if device.startswith('cuda'):
                torch.cuda.synchronize()
            start = time.perf_counter()
            result = network(tensor)
            if device.startswith('cuda'):
                torch.cuda.synchronize()
            timings.append((time.perf_counter()-start)*1000)
            detections = postprocess_rfdetr(result['pred_boxes'].cpu().numpy(), result['pred_logits'].cpu().numpy(), categories,
                                           image.width, image.height, .001, model.model_config.num_select)
            for detection in detections:
                box = detection['boundingBox']
                prediction = {'image_id': row['id'], 'category_id': detection['classId'], 'score': detection['confidence'],
                              'bbox': [box['x1'], box['y1'], box['x2']-box['x1'], box['y2']-box['y1']]}
                predictions.append(prediction)
                if masks and 'pred_masks' in result:
                    from pycocotools import mask as mask_utils
                    raw = result['pred_masks'][0, detection['_query']]
                    resized = torch.nn.functional.interpolate(raw[None, None].float(), size=(image.height, image.width), mode='bilinear', align_corners=False)[0, 0]
                    encoded = mask_utils.encode(np.asfortranarray((resized > 0).cpu().numpy().astype(np.uint8)))
                    encoded['counts'] = encoded['counts'].decode('ascii')
                    mask_predictions.append({k:v for k,v in prediction.items() if k != 'bbox'} | {'segmentation': encoded})
            del result, tensor, image
    report = {'checkpoint': str(checkpoint), 'checkpoint_sha256': hashlib.sha256(checkpoint.read_bytes()).hexdigest(),
              'split': data.stem, 'split_sha256': hashlib.sha256(data.read_bytes()).hexdigest(),
              'input_size': size, 'device': device, 'damage': score(document, 'damage', predictions, threshold),
              'forward_ms_median': float(np.median(timings)), 'predictions': predictions,
              'preprocessing': 'RGB-square-PIL-bilinear-ImageNet-v1' if antialias else 'RGB-square-bilinear-no-antialias-ImageNet-v1', 'production_approved': False}
    if mask_predictions:
        report['segmentation'] = score(document, 'damage', mask_predictions, threshold, 'segm')
    if data.stem == 'val':
        report['calibration'] = calibrate(document, 'damage', predictions)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ('predictions', 'calibration')}), flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkpoint', type=Path, required=True)
    parser.add_argument('--data', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--device', default='cuda')
    parser.add_argument('--size', type=int)
    parser.add_argument('--threshold', type=float, default=.25)
    parser.add_argument('--masks', action='store_true')
    parser.add_argument('--antialias', action=argparse.BooleanOptionalAction, default=True, help='Match framework validation PIL bilinear resize; --no-antialias reproduces its predict() tensor resize')
    args = parser.parse_args()
    evaluate(args.checkpoint, args.data, args.output, args.device, args.size, args.threshold, args.masks, args.antialias)
