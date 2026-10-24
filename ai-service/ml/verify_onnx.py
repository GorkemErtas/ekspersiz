"""Evaluate the selected FP32 ONNX graph on the same frozen independent test."""
import argparse
import json
from pathlib import Path

import onnxruntime as ort
import torch

from .data import CocoTasks
from .evaluate import evaluate


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle',type=Path,default=Path('models/hitl-416'))
    p.add_argument('--data',type=Path,default=Path('datasets/hitl-coco/test.json'))
    p.add_argument('--reference',type=Path,default=Path('evaluation-runs/hitl-final/test.json'))
    p.add_argument('--output',type=Path,default=Path('../docs/ml/HITL_ONNX_ACCURACY.json'))
    a=p.parse_args();manifest=json.loads((a.bundle/'manifest.json').read_text())
    options=ort.SessionOptions();options.intra_op_num_threads=2;options.inter_op_num_threads=1
    session=ort.InferenceSession(str(a.bundle/'model.onnx'),sess_options=options,providers=['CPUExecutionProvider'])
    class Adapter:
        def eval(self):return self
        def __call__(self,images):
            return tuple(torch.from_numpy(x) for x in session.run(['damage','part'],{'images':images.cpu().numpy()}))
    result=evaluate(Adapter(),CocoTasks(a.data,manifest['input_size']),'cpu')
    reference=json.loads(a.reference.read_text())
    delta={t:{k:result['tasks'][t][k]-reference['tasks'][t][k] for k in ('mAP50_95','mAP50','precision','recall','f1')}
           for t in ('damage','part')}
    passed=all(abs(delta[t][k])<=.001 for t in delta for k in ('mAP50_95','mAP50'))
    result.pop('predictions',None)
    report={'input_size':manifest['input_size'],'independent_test':result,'difference_from_pytorch':delta,
            'parity_passed':passed,'production_approved':False,
            'note':'ONNX accuracy parity does not make the underlying low-recall model production ready.'}
    a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'parity_passed':passed,'differences':delta}),flush=True)
    if not passed:raise RuntimeError('ONNX accuracy parity gate failed')


if __name__=='__main__':
    main()
