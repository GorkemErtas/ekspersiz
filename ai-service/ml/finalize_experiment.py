"""Select resolution on validation, then evaluate a fixed independent test split."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import torch
from PIL import Image

from .data import CocoTasks
from .model import load_checkpoint
from .evaluate import evaluate
from .export import export


def clean(result):
    return {k:v for k,v in result.items() if k!='predictions'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--checkpoint',type=Path,required=True)
    p.add_argument('--data',type=Path,default=Path('datasets/hitl-coco'))
    p.add_argument('--output',type=Path,default=Path('evaluation-runs/hitl-final'))
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    device='cuda' if torch.cuda.is_available() else 'cpu'
    model,state=load_checkpoint(a.checkpoint,device)
    torch.set_num_threads(2)
    validation={}
    for size in (416,640):
        result=evaluate(model,CocoTasks(a.data/'val.json',size),device)
        (a.output/f'val-{size}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
        validation[str(size)]=clean(result)
        print(json.dumps({'phase':'validation','size':size,'tasks':{t:m['mAP50_95'] for t,m in result['tasks'].items()}}),flush=True)
    selected=max((416,640),key=lambda size:sum(m['mAP50_95'] for m in validation[str(size)]['tasks'].values())/2)
    # Selection happens before touching the test set; freeze it as an artifact.
    choice={'size':selected,'criterion':'Mean damage/part mAP50:95 on validation only',
            'checkpoint_sha256':hashlib.sha256(a.checkpoint.read_bytes()).hexdigest()}
    (a.output/'selection.json').write_text(json.dumps(choice,indent=2),encoding='utf-8')
    test=evaluate(model,CocoTasks(a.data/'test.json',selected),device)
    (a.output/'test.json').write_text(json.dumps(test,ensure_ascii=False,indent=2),encoding='utf-8')
    # Candidate bundles remain unapproved even if parity passes.
    source=json.loads((a.data/'val.json').read_text(encoding='utf-8'))
    sample=Path(source['info']['source_root'])/source['images'][0]['file_name']
    benchmarks={}
    for size in (416,640):
        bundle=Path(f'models/hitl-{size}')
        export(a.checkpoint,bundle,sample,size)
        benchmark_path=a.output/f'cpu-{size}.json'
        subprocess.run([sys.executable,'-m','ml.benchmark','--bundle',str(bundle),'--image',str(sample),
                        '--output',str(benchmark_path)],check=True)
        benchmarks[str(size)]={'parity':json.loads((bundle/'benchmark.json').read_text()),
                               'runtime':json.loads(benchmark_path.read_text())}
    large=a.output/'large-photo.jpg'
    with Image.open(sample) as image:
        image.convert('RGB').resize((4032,3024)).save(large,quality=85)
    large_report=a.output/'cpu-large-photo.json'
    subprocess.run([sys.executable,'-m','ml.benchmark','--bundle',f'models/hitl-{selected}',
                    '--image',str(large),'--output',str(large_report)],check=True)
    result={'schema_version':'hitl-v1','training':{'checkpoint':str(a.checkpoint),'selected_epoch':state['epoch'],
        'pretrained':state['pretrained'],'configuration':state['config'],
        'parameters':sum(p.numel() for p in model.parameters()),
        'checkpoint_sha256':choice['checkpoint_sha256']},
        'validation':validation,'resolution_selection':choice,'independent_test':clean(test),
        'onnx':benchmarks,'large_photo_cpu':json.loads(large_report.read_text()),
        'production_approved':False,
        'limitations':['No pretrained weights were used; source license for external weights remains unverified.',
            'Both resolutions use the same checkpoint trained at 416; this is not a two-training-run comparison.',
            'Damage-instance/part-instance relationship ground truth is absent; matching accuracy is not measured.',
            'No validated clean-car/nonvehicle negatives or severity/replacement labels; no no-damage certification.',
            'Docker daemon unavailable; live Railway, physical devices and paid external services not exercised.']}
    out=Path('../docs/ml');out.mkdir(parents=True,exist_ok=True)
    (out/'HITL_RESULTS.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'selected_size':selected,'test':{t:{k:m[k] for k in ('mAP50_95','mAP50','precision','recall','f1')} for t,m in test['tasks'].items()}}),flush=True)


if __name__=='__main__':
    main()
