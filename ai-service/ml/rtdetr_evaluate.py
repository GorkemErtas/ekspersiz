"""Evaluate the actual selected RT-DETR safetensors on the same canonical holdout."""
import argparse
import hashlib
import os
from pathlib import Path
import sys

from transformers import RTDetrForObjectDetection
import torch

from .rtdetr_train import evaluate,write


def evaluate_checkpoint(checkpoint,data,output,device='cpu'):
    os.environ['HF_HUB_OFFLINE']='1'
    for stream in (sys.stdout,sys.stderr):
        if hasattr(stream,'reconfigure'):
            stream.reconfigure(encoding='utf-8')
    torch.set_num_threads(4)
    model=RTDetrForObjectDetection.from_pretrained(checkpoint,local_files_only=True).to(device).eval()
    result=evaluate(model,data,device)
    result.update(checkpoint=str(checkpoint),checkpoint_sha256=hashlib.sha256((checkpoint/'model.safetensors').read_bytes()).hexdigest(),
                  input_size=640,device=device)
    write(output,result)
    print({k:v for k,v in result.items() if k not in ('predictions','calibration')},flush=True)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkpoint',type=Path,required=True)
    parser.add_argument('--data',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--device',default='cpu')
    args=parser.parse_args()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    evaluate_checkpoint(args.checkpoint,args.data,args.output,args.device)
