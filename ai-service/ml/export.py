"""Export one checkpoint/two heads and validate actual CPU ONNX parity."""
import argparse
import hashlib
import json
from pathlib import Path
import time

import numpy as np
from PIL import Image
import torch

from app.vision.processing import preprocess
from .model import load_checkpoint


def export(checkpoint, output, image_path, size=416, repeats=10):
    import onnx
    import onnxruntime as ort
    output.mkdir(parents=True,exist_ok=True)
    model,state=load_checkpoint(checkpoint)
    model.eval();torch.set_num_threads(2)
    with Image.open(image_path) as source:
        image=source.convert('RGB')
    pixels,_=preprocess(image,size)
    tensor=torch.from_numpy(pixels[None])
    with torch.inference_mode():
        expected=model(tensor)
    onnx_path=output/'model.onnx'
    torch.onnx.export(model,(tensor,),str(onnx_path),input_names=['images'],
        output_names=['damage','part'],opset_version=17,dynamo=False)
    onnx.checker.check_model(str(onnx_path))
    options=ort.SessionOptions();options.intra_op_num_threads=2;options.inter_op_num_threads=1
    start=time.perf_counter()
    session=ort.InferenceSession(str(onnx_path),sess_options=options,providers=['CPUExecutionProvider'])
    load_ms=(time.perf_counter()-start)*1000
    actual=session.run(None,{'images':pixels[None]})
    parity={}
    for task,a,b in zip(('damage','part'),expected,actual):
        a=a.detach().numpy()
        np.testing.assert_allclose(a,b,rtol=1e-3,atol=.02)
        parity[task]={'shape':list(b.shape),'max_absolute_error':float(np.abs(a-b).max())}
    times=[]
    for _ in range(repeats):
        start=time.perf_counter();session.run(None,{'images':pixels[None]});times.append((time.perf_counter()-start)*1000)
    catalog_bytes=(json.dumps(state['catalog'],ensure_ascii=False,indent=2)+'\n').encode()
    (output/'classes.json').write_bytes(catalog_bytes)
    report={'input_size':size,'parity':parity,'session_load_ms':load_ms,
        'cpu_forward_ms_median':float(np.median(times)),'cpu_forward_ms_p95':float(np.percentile(times,95)),
        'repeats':repeats,'checkpoint_epoch':state['epoch'],
        'checkpoint_sha256':hashlib.sha256(checkpoint.read_bytes()).hexdigest(),
        'note':'Parity and latency do not establish detection accuracy or production readiness.'}
    (output/'benchmark.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    manifest={'schema_version':'hitl-v1','model_version':f'hitl-tiny-epoch-{state["epoch"]}',
        'input_size':size,'input_color':'BGR','outputs':['damage','part'],
        'model_sha256':hashlib.sha256(onnx_path.read_bytes()).hexdigest(),
        'catalog_sha256':hashlib.sha256(catalog_bytes).hexdigest(),
        'training_data_sha256':state['training_data_sha256'],
        'validation_data_sha256':state['validation_data_sha256'],
        'pretrained':state['pretrained'],'production_approved':False,
        'threshold':.25,'nms_threshold':.45,
        'approval_note':'Requires independent task evaluation, paired matching review, calibration, and explicit release approval.'}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    notices=Path(__file__).parent/'vendor/yolox'
    (output/'LICENSE.YOLOX').write_bytes((notices/'LICENSE').read_bytes())
    (output/'NOTICE.YOLOX.md').write_bytes((notices/'NOTICE.md').read_bytes())
    print(json.dumps(report),flush=True)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--checkpoint',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--image',type=Path,required=True)
    p.add_argument('--size',type=int,default=416)
    p.add_argument('--repeats',type=int,default=10)
    a=p.parse_args();export(a.checkpoint,a.output,a.image,a.size,a.repeats)


if __name__=='__main__':
    main()
