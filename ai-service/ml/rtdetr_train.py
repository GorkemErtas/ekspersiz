"""Actual licensed RT-DETR R18 fine-tuning; validation-only checkpoint selection."""
import argparse
from collections import defaultdict
import copy
import hashlib
from importlib.metadata import version
import json
import math
import os
from pathlib import Path
import random
import sys
import time

import numpy as np
from PIL import Image
import torch
from torch.utils.data import Dataset, DataLoader
from torchvision.transforms import ColorJitter
from transformers import RTDetrForObjectDetection
from transformers.models.rt_detr.image_processing_pil_rt_detr import RTDetrImageProcessorPil

from app.vision.rfdetr_processing import postprocess_rfdetr
from app.vision.rtdetr_processing import preprocess_rtdetr
from .metrics import score, calibrate


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, default=str)+'\n', encoding='utf-8')


class TrainingView(Dataset):
    def __init__(self, directory):
        self.directory = directory
        doc = json.loads((directory/'_annotations.coco.json').read_text(encoding='utf-8'))
        self.rows = doc['images']
        self.annotations = defaultdict(list)
        self.colors = ColorJitter(.15,.15,.1,.02)
        for annotation in doc['annotations']:
            self.annotations[annotation['image_id']].append(annotation)

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, index):
        row = self.rows[index]
        with Image.open(self.directory/row['file_name']) as source:
            image = source.convert('RGB')
        annotations = [{k:copy.deepcopy(a[k]) for k in ('id','category_id','bbox','area','iscrowd')} for a in self.annotations[row['id']]]
        if random.random() < .5:
            image = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            for annotation in annotations:
                x,y,w,h = annotation['bbox']
                annotation['bbox'] = [image.width-x-w,y,w,h]
        if random.random() < .5:
            image = self.colors(image)
        return image, {'image_id':row['id'],'annotations':annotations}


def evaluate(model, data, device, output=None):
    document = json.loads(data.read_text(encoding='utf-8'))
    canonical = json.loads((Path(__file__).resolve().parents[1]/'app/vision/classes.json').read_text(encoding='utf-8'))
    categories = sorted((c for c in canonical['categories'] if c['task'] == 'damage'), key=lambda c:c['task_index'])
    if [model.config.id2label[i] for i in range(model.config.num_labels)] != [c['name'] for c in categories]:
        raise ValueError('RT-DETR class identity differs from the canonical catalog')
    if any(c not in canonical['categories'] for c in document['categories']):
        raise ValueError('Evaluation class identity differs from the canonical catalog')
    root = Path(document['info']['source_root'])
    predictions = []
    model.eval()
    with torch.inference_mode():
        for row in document['images']:
            if 'damage' not in row['tasks']:
                continue
            with Image.open(root/row['file_name']) as source:
                image = source.convert('RGB')
            tensor = torch.from_numpy(preprocess_rtdetr(image)[None]).to(device)
            result = model(pixel_values=tensor)
            detections = postprocess_rfdetr(result.pred_boxes.float().cpu().numpy(), result.logits.float().cpu().numpy(),
                                           categories, image.width,image.height,.001,300,background_class=False)
            for detection in detections:
                box = detection['boundingBox']
                predictions.append({'image_id':row['id'],'category_id':detection['classId'], 'score':detection['confidence'],
                                    'bbox':[box['x1'],box['y1'],box['x2']-box['x1'],box['y2']-box['y1']]})
    result = {'split':data.stem,'split_sha256':hashlib.sha256(data.read_bytes()).hexdigest(),
              'damage':score(document,'damage',predictions), 'predictions':predictions,
              'preprocessing':'RGB-square-PIL-bilinear-rescale01-v1','production_approved':False}
    if data.stem == 'val':
        result['calibration'] = calibrate(document,'damage',predictions)
    if output:
        write(output,result)
    return result


def train(args):
    for stream in (sys.stdout,sys.stderr):
        if hasattr(stream,'reconfigure'):
            stream.reconfigure(encoding='utf-8')
    os.environ['HF_HUB_OFFLINE'] = '1'
    if version('transformers') != '5.20.2' or not torch.cuda.is_available():
        raise RuntimeError('Use reviewed Transformers 5.20.2 and an actual CUDA GPU')
    if args.output.exists():
        raise ValueError('Use a fresh run directory')
    torch.set_num_threads(4)
    random.seed(2026)
    np.random.seed(2026)
    torch.manual_seed(2026)
    torch.cuda.manual_seed_all(2026)
    publisher = json.loads((args.pretrained/'publisher.json').read_text(encoding='utf-8'))
    if publisher['repository'] != 'PekingU/rtdetr_r18vd' or publisher['license'] != 'Apache-2.0':
        raise ValueError('Unreviewed pretrained model')
    if hashlib.sha256((args.pretrained/'model.safetensors').read_bytes()).hexdigest() != publisher['files']['model.safetensors']['sha256']:
        raise ValueError('Pretrained safetensors checksum mismatch')
    provenance = json.loads((args.data/'provenance.json').read_text(encoding='utf-8'))
    if provenance['test_exposed_to_training'] is not False or (args.data/'test').exists():
        raise ValueError('Test must not be exposed to training')
    categories = json.loads(Path('app/vision/classes.json').read_text(encoding='utf-8'))['categories']
    labels = {c['task_index']:c['name'] for c in categories if c['task']=='damage'}
    model, loading = RTDetrForObjectDetection.from_pretrained(args.pretrained, local_files_only=True,
        num_labels=8,id2label=labels,label2id={v:k for k,v in labels.items()},ignore_mismatched_sizes=True,output_loading_info=True)
    loading = {key: sorted(value) if isinstance(value,set) else value for key,value in loading.items()}
    unexpected = loading.get('unexpected_keys',[])
    missing = list(loading.get('missing_keys',[]))
    mismatched = [row[0] if not isinstance(row,str) else row for row in loading.get('mismatched_keys',[])]
    if unexpected or any(not any(token in key for token in ('class_embed','enc_score_head','denoising_class_embed')) for key in missing+mismatched):
        raise ValueError(f'Unexpected pretrained transfer coverage: {loading}')
    model.config.disable_custom_kernels = True
    model.to('cuda')
    ema = copy.deepcopy(model).eval().requires_grad_(False)
    processor = RTDetrImageProcessorPil.from_pretrained(args.pretrained, local_files_only=True)
    if processor.do_normalize or not processor.do_rescale or processor.size != {'height':640,'width':640}:
        raise ValueError('Publisher preprocessing differs from the reviewed RGB rescale-only profile')
    # Verify the offline/ONNX preprocessing against the publisher processor before training.
    sample = Image.fromarray(np.random.default_rng(2026).integers(0,256,(419,637,3),dtype=np.uint8))
    np.testing.assert_allclose(preprocess_rtdetr(sample),processor(images=sample,return_tensors='np')['pixel_values'][0],atol=1e-7,rtol=1e-6)
    dataset = TrainingView(args.data/'train')
    def collate(rows):
        images, annotations = zip(*rows)
        return processor(images=list(images),annotations=list(annotations),return_tensors='pt')
    loader = DataLoader(dataset,batch_size=args.batch,shuffle=True,num_workers=0,collate_fn=collate)
    groups = [dict(params=[p for name,p in model.named_parameters() if p.requires_grad and 'backbone' not in name],lr=1e-4),
              dict(params=[p for name,p in model.named_parameters() if p.requires_grad and 'backbone' in name],lr=5e-5)]
    optimizer = torch.optim.AdamW(groups,weight_decay=1e-4)
    steps_per_epoch = math.ceil(len(loader)/args.accumulate)
    total_steps = steps_per_epoch*args.epochs
    def schedule(step):
        if step < steps_per_epoch:
            return (step+1)/steps_per_epoch
        progress = (step-steps_per_epoch)/max(total_steps-steps_per_epoch,1)
        return .01+.99*(1+math.cos(math.pi*min(progress,1)))/2
    scheduler = torch.optim.lr_scheduler.LambdaLR(optimizer,schedule)
    args.output.mkdir(parents=True)
    record = {'variant':'rtdetr-r18','status':'started','input_size':640,'seed':2026,
              'gpu':torch.cuda.get_device_name(),'torch':torch.__version__,'transformers':version('transformers'),
              'pretrained':publisher,'pretrained_loading_info':loading,'model_config':model.config.to_dict(),
              'provenance':provenance,'maximum_epochs':args.epochs,'batch_size':args.batch,
              'gradient_accumulation':args.accumulate,'lr':1e-4,'backbone_lr':5e-5,
              'weight_decay':1e-4,'gradient_clip':.1,'ema':'min(0.9999,(1+step)/(10+step))',
              'production_approved':False,'preprocessing_reference_check_passed':True,
              'image_processor_backend':'pil','epochs':[]}
    write(args.output/'experiment.json',record)
    best, best_epoch, stale, step = -1., -1, 0, 0
    started = time.perf_counter()
    try:
        for epoch in range(args.epochs):
            model.train()
            optimizer.zero_grad(set_to_none=True)
            total_loss = 0.
            for index,batch in enumerate(loader):
                pixels = batch['pixel_values'].to('cuda')
                targets = [{k:v.to('cuda') if torch.is_tensor(v) else v for k,v in target.items()} for target in batch['labels']]
                with torch.autocast('cuda',dtype=torch.bfloat16):
                    outputs = model(pixel_values=pixels,labels=targets)
                    loss = outputs.loss/args.accumulate
                if not torch.isfinite(loss):
                    raise ValueError('Nonfinite actual training loss')
                loss.backward()
                total_loss += float(outputs.loss.detach())
                if (index+1)%args.accumulate == 0 or index+1 == len(loader):
                    torch.nn.utils.clip_grad_norm_(model.parameters(),.1)
                    optimizer.step()
                    optimizer.zero_grad(set_to_none=True)
                    scheduler.step()
                    step += 1
                    decay = min(.9999,(1+step)/(10+step))
                    with torch.no_grad():
                        source = model.state_dict()
                        for name,value in ema.state_dict().items():
                            if value.is_floating_point():
                                value.mul_(decay).add_(source[name],alpha=1-decay)
                            else:
                                value.copy_(source[name])
                if (index+1)%40 == 0:
                    print(json.dumps({'epoch':epoch,'batch':index+1,'batches':len(loader),'loss':total_loss/(index+1)}),flush=True)
                del outputs,loss,pixels,targets
            candidates = []
            for name,network in (('base',model),('ema',ema)):
                result = evaluate(network,args.canonical/'val.json','cuda')
                candidates.append((result['damage']['mAP50_95'],name,network,result))
            metric,name,network,result = max(candidates,key=lambda row:row[0])
            epoch_record = {'epoch':epoch,'loss':total_loss/len(loader),'selected_weights':name,
                            'validation':{name:result['damage']['mAP50_95'] for _,name,_,result in candidates},
                            'mAP50_95':metric,'elapsed_seconds':time.perf_counter()-started}
            record['epochs'].append(epoch_record)
            if metric > best:
                best,best_epoch,stale = metric,epoch,0
                network.save_pretrained(args.output/'best',safe_serialization=True)
                processor.save_pretrained(args.output/'best')
                write(args.output/'best-val.json',result)
            else:
                stale += 1
            record.update(best_epoch=best_epoch,best_validation_mAP50_95=best,
                          cuda_peak_mib=torch.cuda.max_memory_allocated()/1024**2,
                          elapsed_seconds=time.perf_counter()-started)
            write(args.output/'experiment.json',record)
            print(json.dumps(epoch_record),flush=True)
            if stale >= 10:
                break
        record['status'] = 'completed'
    except BaseException as error:
        record.update(status='failed',failure=repr(error))
        raise
    finally:
        record.update(elapsed_seconds=time.perf_counter()-started,cuda_peak_mib=torch.cuda.max_memory_allocated()/1024**2)
        write(args.output/'experiment.json',record)
    print(json.dumps({'status':record['status'],'best_epoch':best_epoch,'mAP50_95':best}),flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pretrained',type=Path,default=Path('models/pretrained-rtdetr-r18'))
    parser.add_argument('--data',type=Path,default=Path('datasets/transfer-damage-balanced'))
    parser.add_argument('--canonical',type=Path,default=Path('datasets/hitl-coco'))
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--epochs',type=int,default=30)
    parser.add_argument('--batch',type=int,default=4)
    parser.add_argument('--accumulate',type=int,default=2)
    train(parser.parse_args())
