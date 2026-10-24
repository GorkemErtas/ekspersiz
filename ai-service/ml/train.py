"""Reproducible task-aware training. Checkpoints are never production approval."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import random
import time

import numpy as np
import torch
from torch.utils.data import DataLoader

from .data import CocoTasks, collate
from .model import UnifiedYOLOXTiny, TASKS, load_checkpoint
from .evaluate import evaluate


def train(args):
    if args.size % 32 or args.size < 128 or args.accumulate < 1 or args.batch < 2:
        raise ValueError('Use size >=128 divisible by 32, batch >=2, accumulate >=1')
    os.environ.setdefault('CUBLAS_WORKSPACE_CONFIG',':4096:8')
    random.seed(args.seed);np.random.seed(args.seed);torch.manual_seed(args.seed)
    torch.use_deterministic_algorithms(True,warn_only=True)
    torch.set_num_threads(min(4,os.cpu_count() or 1))
    torch.backends.cudnn.benchmark=False
    args.output.mkdir(parents=True,exist_ok=True)
    if (args.output/'last.pth').exists() and args.resume is None:
        raise ValueError('Output contains a checkpoint; use --resume or a new output directory')
    train_data=CocoTasks(args.data/'train.json',args.size,True,args.smoke)
    val_data=CocoTasks(args.data/'val.json',args.size,False,args.smoke)
    if len(train_data)<args.batch or not val_data.images:
        raise ValueError('Insufficient train/validation images')
    train_groups={r['group_id'] for r in train_data.images}
    if train_groups & {r['group_id'] for r in val_data.images}:
        raise ValueError('Train/validation group leakage')
    catalog=json.loads((args.data/'classes.json').read_text(encoding='utf-8'))
    counts=tuple(sum(c['task']==t for c in catalog['categories']) for t in TASKS)
    model=UnifiedYOLOXTiny(counts).to(args.device)
    optimizer=torch.optim.SGD(model.parameters(),lr=args.lr,momentum=.9,weight_decay=5e-4,nesterov=True)
    generator=torch.Generator().manual_seed(args.seed)
    loader=DataLoader(train_data,batch_size=args.batch,sampler=train_data.sampler(generator),
                      collate_fn=collate,num_workers=0,drop_last=True)
    steps=len(loader)
    config={k:str(v) if isinstance(v,Path) else v for k,v in vars(args).items()}
    (args.output/'config.json').write_text(json.dumps(config,indent=2),encoding='utf-8')
    start_epoch=0;best=-1.;stale=0
    if args.resume:
        model,checkpoint=load_checkpoint(args.resume,args.device)
        if checkpoint['catalog']!=catalog or checkpoint['config']['size']!=args.size:
            raise ValueError('Resume catalog/input size mismatch')
        optimizer=torch.optim.SGD(model.parameters(),lr=args.lr,momentum=.9,weight_decay=5e-4,nesterov=True)
        optimizer.load_state_dict(checkpoint['optimizer'])
        start_epoch=checkpoint['epoch']+1;best=checkpoint['best'];stale=checkpoint['stale']
        torch.set_rng_state(checkpoint['torch_rng'].cpu())
        generator.set_state(checkpoint['sampler_rng'].cpu())
        random.setstate(checkpoint['python_rng'])
        if 'cuda_rng' in checkpoint and torch.cuda.is_available():
            torch.cuda.set_rng_state_all([state.cpu() for state in checkpoint['cuda_rng']])
    for epoch in range(start_epoch,args.epochs):
        started=time.perf_counter();model.train();optimizer.zero_grad(set_to_none=True)
        sums={t:0. for t in TASKS}
        for step,(images,targets,mask,_) in enumerate(loader):
            global_step=epoch*steps+step
            warmup=max(steps*3,1)
            factor=min(1.,(global_step+1)/warmup)**2
            if global_step>=warmup:
                factor=.05+.95*(1+math.cos(math.pi*(global_step-warmup)/max(args.epochs*steps-warmup,1)))/2
            for group in optimizer.param_groups:
                group['lr']=args.lr*factor
            losses=model(images.to(args.device),{t:x.to(args.device) for t,x in targets.items()},mask.to(args.device))
            group_size=min(args.accumulate,steps-(step//args.accumulate)*args.accumulate)
            total=(losses['damage']*args.damage_weight+losses['part']*args.part_weight)/group_size
            if not torch.isfinite(total):
                raise RuntimeError('Nonfinite loss: training stopped, no checkpoint promoted')
            total.backward()
            if (step+1)%args.accumulate==0 or step+1==steps:
                torch.nn.utils.clip_grad_norm_(model.parameters(),10.)
                optimizer.step();optimizer.zero_grad(set_to_none=True)
            for t,v in losses.items():
                sums[t]+=float(v.detach())
        metrics = evaluate(model,val_data,args.device) if (epoch+1)%args.eval_every==0 or epoch+1==args.epochs else None
        score=float(np.mean([m['mAP50_95'] for m in metrics['tasks'].values() if 'mAP50_95' in m])) if metrics else best
        improved=score>best
        stale=0 if improved else stale+int(metrics is not None)
        best=max(best,score)
        state={'schema_version':'hitl-v1','model':model.state_dict(),'optimizer':optimizer.state_dict(),
            'catalog':catalog,'config':config,'epoch':epoch,'best':best,'stale':stale,
            'torch_rng':torch.get_rng_state(),'sampler_rng':generator.get_state(),'python_rng':random.getstate(),
            'training_data_sha256':hashlib.sha256((args.data/'train.json').read_bytes()).hexdigest(),
            'validation_data_sha256':hashlib.sha256((args.data/'val.json').read_bytes()).hexdigest(),
            'pretrained':None,'production_approved':False}
        if torch.cuda.is_available():
            state['cuda_rng']=torch.cuda.get_rng_state_all()
        temporary=args.output/'last.tmp'
        torch.save(state,temporary);temporary.replace(args.output/'last.pth')
        if improved:
            torch.save(state,args.output/'best.pth')
        log={'epoch':epoch,'seconds':time.perf_counter()-started,'mean_loss':{t:v/steps for t,v in sums.items()},
            'validation':{t:{k:m[k] for k in ('mAP50_95','mAP50','precision','recall','f1')} for t,m in metrics['tasks'].items()} if metrics else None,
            'cuda_peak_mib':torch.cuda.max_memory_allocated()/1024**2 if torch.cuda.is_available() else None}
        with (args.output/'training.jsonl').open('a',encoding='utf-8') as f:
            f.write(json.dumps(log)+'\n')
        print(json.dumps(log),flush=True)
        if stale>=args.patience and epoch>=5:
            break
    return model


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data',type=Path,default=Path('datasets/hitl-coco'))
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--epochs',type=int,default=50)
    p.add_argument('--size',type=int,default=416)
    p.add_argument('--batch',type=int,default=8)
    p.add_argument('--accumulate',type=int,default=1)
    p.add_argument('--lr',type=float,default=.005)
    p.add_argument('--patience',type=int,default=15)
    p.add_argument('--eval-every',type=int,default=5)
    p.add_argument('--seed',type=int,default=2026)
    p.add_argument('--damage-weight',type=float,default=1.)
    p.add_argument('--part-weight',type=float,default=1.)
    p.add_argument('--device',default='cuda' if torch.cuda.is_available() else 'cpu')
    p.add_argument('--smoke',type=int,help='Limit images per task; not a quality evaluation')
    p.add_argument('--resume',type=Path)
    train(p.parse_args())


if __name__=='__main__':
    main()
