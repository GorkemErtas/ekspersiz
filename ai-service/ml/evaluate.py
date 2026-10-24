"""COCO metrics restricted to each task's annotated images, never missing labels."""
import argparse
import contextlib
import io
import json
from pathlib import Path
import time

import numpy as np
import torch
from torch.utils.data import DataLoader

from app.vision.processing import postprocess, iou
from .data import CocoTasks, collate
from .model import load_checkpoint, TASKS


def evaluate(model, dataset, device, threshold=.25):
    from pycocotools.coco import COCO
    from pycocotools.cocoeval import COCOeval
    model.eval()
    predictions = {t:[] for t in TASKS}
    times = []
    by_id = {r['id']:r for r in dataset.images}
    catalogs = {t:sorted([c for c in dataset.categories.values() if c['task']==t],key=lambda c:c['task_index']) for t in TASKS}
    loader = DataLoader(dataset,batch_size=1,shuffle=False,collate_fn=collate,num_workers=0)
    with torch.inference_mode():
        for images, _, mask, ids in loader:
            images = images.to(device)
            if str(device).startswith('cuda'):
                torch.cuda.synchronize()
            start = time.perf_counter()
            outputs = model(images)
            if str(device).startswith('cuda'):
                torch.cuda.synchronize()
            times.append((time.perf_counter()-start)*1000)
            row = by_id[ids[0]]
            ratio = min(dataset.size/row['width'],dataset.size/row['height'])
            for index, task in enumerate(TASKS):
                if not mask[0,index]:
                    continue
                detections = postprocess(outputs[index].cpu().numpy(),catalogs[task],ratio,row['width'],row['height'],threshold=.001)
                for d in detections:
                    b = d['boundingBox']
                    predictions[task].append({'image_id':row['id'],'category_id':d['classId'],
                        'bbox':[b['x1'],b['y1'],b['x2']-b['x1'],b['y2']-b['y1']], 'score':d['confidence']})
    results = {}
    for task in TASKS:
        images = [r for r in dataset.images if task in r['tasks']]
        ids = {r['id'] for r in images}
        cats = catalogs[task]
        cat_ids = {c['id'] for c in cats}
        anns = [a for a in dataset.document['annotations'] if a['image_id'] in ids and a['category_id'] in cat_ids]
        if not ids:
            results[task] = {'status':'NO_ANNOTATED_IMAGES'}
            continue
        with contextlib.redirect_stdout(io.StringIO()):
            gt = COCO()
            gt.dataset = {'images':images,'annotations':anns,'categories':cats,'info':{}}
            gt.createIndex()
            if predictions[task]:
                dt = gt.loadRes(predictions[task])
            else:
                dt = COCO(); dt.dataset = {'images':images,'annotations':[],'categories':cats}; dt.createIndex()
            metric = COCOeval(gt,dt,'bbox')
            metric.params.imgIds = sorted(ids)
            metric.params.catIds = sorted(cat_ids)
            metric.evaluate(); metric.accumulate(); metric.summarize()
        per_class = {}
        for k,c in enumerate(sorted(cats,key=lambda c:c['id'])):
            precision = metric.eval['precision'][:,:,k,0,-1]
            valid = precision[precision>=0]
            p50 = precision[0]; p50 = p50[p50>=0]
            per_class[c['name']] = {'mAP50_95':float(valid.mean()) if len(valid) else None,
                'mAP50':float(p50.mean()) if len(p50) else None,
                'annotations':sum(a['category_id']==c['id'] for a in anns)}
        # Operating-point confusion matrix (rows truth, columns predictions; last is background).
        category_order = sorted(cat_ids)
        indices = {c:i for i,c in enumerate(category_order)}
        confusion = np.zeros((len(cats)+1,len(cats)+1),dtype=int)
        tp=fp=fn=0
        for image_id in ids:
            truth = [a for a in anns if a['image_id']==image_id]
            pred = sorted([p for p in predictions[task] if p['image_id']==image_id and p['score']>=threshold],key=lambda p:p['score'],reverse=True)
            used = set()
            def xyxy(box):
                x,y,w,h=box;return np.array((x,y,x+w,y+h))
            for p in pred:
                options = [(iou(xyxy(p['bbox']),xyxy(a['bbox'])),j) for j,a in enumerate(truth) if j not in used]
                overlap,j = max(options,default=(0,-1))
                if overlap>=.5:
                    used.add(j);a=truth[j]
                    confusion[indices[a['category_id']],indices[p['category_id']]] += 1
                    if a['category_id']==p['category_id']:
                        tp+=1
                    else:
                        fp+=1;fn+=1
                else:
                    confusion[-1,indices[p['category_id']]]+=1;fp+=1
            for j,a in enumerate(truth):
                if j not in used:
                    confusion[indices[a['category_id']],-1]+=1;fn+=1
        precision = tp/max(tp+fp,1);recall=tp/max(tp+fn,1)
        results[task] = {'images':len(ids),'mAP50_95':float(metric.stats[0]),'mAP50':float(metric.stats[1]),
            'precision':precision,'recall':recall,'f1':2*precision*recall/max(precision+recall,1e-12),
            'true_positive':tp,'false_positive':fp,'false_negative':fn,'threshold':threshold,
            'per_class':per_class,'confusion_matrix':confusion.tolist(),
            'confusion_class_ids':category_order+['background']}
    return {'tasks':results,'forward_ms_median':float(np.median(times)),
        'paired_task_images':sum(len(r['tasks'])==2 for r in dataset.images),
        'matching_accuracy':None,'matching_note':'No damage-instance to part-instance relationship labels; detection metrics do not validate assignment.',
        'predictions':predictions}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--checkpoint',required=True,type=Path)
    p.add_argument('--data',required=True,type=Path)
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--size',type=int,default=416)
    p.add_argument('--device',default='cuda' if torch.cuda.is_available() else 'cpu')
    a=p.parse_args();model,checkpoint=load_checkpoint(a.checkpoint,a.device)
    dataset=CocoTasks(a.data,a.size)
    if dataset.document['categories'] != checkpoint['catalog']['categories']:
        raise ValueError('Evaluation catalog differs from checkpoint')
    result=evaluate(model,dataset,a.device)
    result.update({'checkpoint':str(a.checkpoint),'data':str(a.data),'size':a.size,'training_epoch':checkpoint['epoch']})
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({t:{k:v for k,v in m.items() if k not in ('per_class','confusion_matrix')} for t,m in result['tasks'].items()}))


if __name__=='__main__':
    main()
