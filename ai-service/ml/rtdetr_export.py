"""Export the actual RT-DETR R18 / unchanged part checkpoint, always unapproved."""
import argparse
import hashlib
from importlib.metadata import distribution
import json
import os
from pathlib import Path
import shutil
import sys

import numpy as np
from PIL import Image
import torch
from torch import nn
from transformers import RTDetrForObjectDetection

from app.vision.rtdetr_processing import preprocess_rtdetr
from app.vision.rfdetr_processing import postprocess_rfdetr
from app.vision.processing import preprocess
from .model import load_checkpoint
from .transfer_export import PartGraph
from .metrics import overlap


class DamageGraph(nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, images):
        result = self.model(pixel_values=images)
        return result.pred_boxes,result.logits


def export(checkpoint, part_checkpoint, experiment, output, images, threshold=.25, smoke=False):
    os.environ['HF_HUB_OFFLINE']='1'
    torch.set_num_threads(2)
    for stream in (sys.stdout,sys.stderr):
        if hasattr(stream,'reconfigure'):
            stream.reconfigure(encoding='utf-8')
    provenance=json.loads(experiment.read_text(encoding='utf-8'))
    if provenance['variant']!='rtdetr-r18' or provenance['pretrained']['license']!='Apache-2.0' or provenance['pretrained']['repository']!='PekingU/rtdetr_r18vd':
        raise ValueError('Unreviewed pretrained provenance')
    if provenance['status']!='completed' and not smoke:
        raise ValueError('Only completed training can be exported as a comparison candidate')
    if output.exists() or not .25<=threshold<=1:
        raise ValueError('Use a new output directory and preserve the API confidence floor')
    output.mkdir(parents=True)
    model=RTDetrForObjectDetection.from_pretrained(checkpoint,local_files_only=True).cpu().eval()
    canonical_path=Path(__file__).resolve().parents[1]/'app/vision/classes.json'
    canonical=json.loads(canonical_path.read_text(encoding='utf-8'))
    categories=sorted((c for c in canonical['categories'] if c['task']=='damage'),key=lambda c:c['task_index'])
    if model.config.num_labels!=8 or [model.config.id2label[i] for i in range(8)]!=[c['name'] for c in categories]:
        raise ValueError('RT-DETR class order mismatch')
    damage=DamageGraph(model).eval()
    part_model,part_metadata=load_checkpoint(part_checkpoint)
    if part_metadata['catalog']!=canonical:
        raise ValueError('Part checkpoint class identity mismatch')
    part=PartGraph(part_model.eval()).eval()
    photos=[]
    for path in images:
        with Image.open(path) as source:
            photos.append(source.convert('RGB'))
    first=torch.from_numpy(preprocess_rtdetr(photos[0])[None])
    torch.onnx.export(damage,first,str(output/'damage.onnx'),input_names=['images'],output_names=['boxes','logits'],opset_version=17,dynamo=False)
    torch.onnx.export(part,torch.from_numpy(preprocess(photos[0],416)[0][None]),str(output/'part.onnx'),input_names=['images'],output_names=['part'],opset_version=17,dynamo=False)
    import onnxruntime as ort
    from scipy.optimize import linear_sum_assignment
    options=ort.SessionOptions()
    options.intra_op_num_threads=2
    options.inter_op_num_threads=1
    session=ort.InferenceSession(str(output/'damage.onnx'),sess_options=options,providers=['CPUExecutionProvider'])
    parity=[]
    for photo in photos:
        tensor=torch.from_numpy(preprocess_rtdetr(photo)[None])
        with torch.inference_mode():
            original=damage(tensor)
        expected=[a.numpy() for a in original]
        observed=session.run(['boxes','logits'],{'images':tensor.numpy()})
        raw_allclose=all(np.allclose(a,b,atol=3e-4,rtol=3e-4) for a,b in zip(observed,expected))
        expected_set=postprocess_rfdetr(*expected,categories,photo.width,photo.height,background_class=False)
        actual_set=postprocess_rfdetr(*observed,categories,photo.width,photo.height,background_class=False)
        if len(expected_set)!=len(actual_set):
            raise ValueError('RT-DETR decoded count differs after export')
        def box(item):
            b=item['boundingBox']
            return [b['x1'],b['y1'],b['x2']-b['x1'],b['y2']-b['y1']]
        costs=np.array([[1-overlap(box(a),box(b))+int(a['classId']!=b['classId']) for b in actual_set] for a in expected_set])
        pairs=linear_sum_assignment(costs) if expected_set else ([],[])
        minimum_iou,maximum_error=1.,0.
        for i,j in zip(*pairs):
            a,b=expected_set[i],actual_set[j]
            if a['classId']!=b['classId']:
                raise ValueError('RT-DETR decoded class differs after export')
            minimum_iou=min(minimum_iou,overlap(box(a),box(b)))
            maximum_error=max(maximum_error,abs(a['confidence']-b['confidence']))
        if minimum_iou<.999 or maximum_error>.001:
            raise ValueError('RT-DETR decoded set differs beyond the declared export tolerance')
        parity.append({'image_size':list(photo.size),'raw_array_allclose':raw_allclose,
                       'maximum_absolute_errors':[float(np.max(np.abs(a-b))) for a,b in zip(observed,expected)],
                       'api_set_parity_passed':True,'minimum_iou':minimum_iou,'maximum_score_error':maximum_error})
    shutil.copyfile(canonical_path,output/'classes.json')
    (output/'training_provenance.json').write_text(json.dumps(provenance,indent=2,default=str)+'\n',encoding='utf-8')
    licenses=output/'licenses'
    licenses.mkdir()
    for path in distribution('transformers').files or []:
        if path.name=='LICENSE':
            shutil.copyfile(distribution('transformers').locate_file(path),licenses/'TRANSFORMERS-APACHE-2.0.txt')
            break
    if not (licenses/'TRANSFORMERS-APACHE-2.0.txt').exists():
        raise ValueError('Missing framework Apache license text')
    shutil.copyfile(Path(__file__).parent/'vendor/yolox/LICENSE',licenses/'YOLOX-LICENSE')
    shutil.copyfile(Path(__file__).parent/'vendor/yolox/NOTICE.md',licenses/'YOLOX-NOTICE.md')
    publisher_card=Path('models/pretrained-rtdetr-r18/README.md')
    if hashlib.sha256(publisher_card.read_bytes()).hexdigest()!=provenance['pretrained']['files']['README.md']['sha256']:
        raise ValueError('Publisher model card identity mismatch')
    shutil.copyfile(publisher_card,licenses/'PRETRAINED-MODEL-CARD.md')
    (licenses/'PRETRAINED-PUBLISHER.json').write_text(json.dumps(provenance['pretrained'],indent=2)+'\n',encoding='utf-8')
    (licenses/'NOTICE.md').write_text('RT-DETR R18 pretrained weights: Peking University publisher model card, Apache-2.0.\n'
        'Implementation: RT-DETR authors and Hugging Face, Transformers Apache-2.0.\n'
        'Part model: Megvii YOLOX Apache-2.0, own scratch-trained HITL CC0 weights.\n'
        'EksperSiz changes: eight-class HITL fine-tuning, two-model ONNX adapter.\n'
        'Experimental and not production approved. COCO source images are not redistributed.\n',encoding='utf-8')
    digest=lambda name:hashlib.sha256((output/name).read_bytes()).hexdigest()
    manifest={'format':'ensemble-v1','schema_version':'hitl-v1','production_approved':False,
              'damage_family':'rtdetr','model_version':'hitl-rtdetr-r18-640-'+hashlib.sha256((checkpoint/'model.safetensors').read_bytes()).hexdigest()[:12],
              'input_sizes':{'damage':640,'part':416},'outputs':['boxes','logits','part'],
              'damage_preprocessing':'RGB-square-PIL-bilinear-rescale01-v1','part_preprocessing':'BGR-letterbox-114-v1',
              'threshold':threshold,'part_threshold':.25,'nms_threshold':.45,'num_queries':300,'num_select':300,
              'damage_checkpoint_sha256':hashlib.sha256((checkpoint/'model.safetensors').read_bytes()).hexdigest(),
              'part_checkpoint_sha256':hashlib.sha256(part_checkpoint.read_bytes()).hexdigest(),
              'damage_sha256':digest('damage.onnx'),'part_sha256':digest('part.onnx'),'catalog_sha256':digest('classes.json'),
              'training_provenance_sha256':digest('training_provenance.json'),'requires_complete_holdout_accuracy_check':True,
              'export_smoke_only':smoke,'parity':parity}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest),flush=True)
    return manifest


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkpoint',type=Path,required=True)
    parser.add_argument('--experiment',type=Path,required=True)
    parser.add_argument('--part-checkpoint',type=Path,default=Path('training-runs/hitl-tiny-416/best.pth'))
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--images',type=Path,nargs='+',required=True)
    parser.add_argument('--threshold',type=float,default=.25)
    parser.add_argument('--smoke',action='store_true')
    args=parser.parse_args()
    export(args.checkpoint,args.part_checkpoint,args.experiment,args.output,args.images,args.threshold,args.smoke)
