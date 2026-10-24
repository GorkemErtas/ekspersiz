import copy
from io import BytesIO
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

from app.vision.processing import decode_image, preprocess, postprocess, match_parts
from app.vision.runtime import UnifiedVisionRuntime, VisionUnavailable
from ml.dataset import convert, polygon, group_images, split_groups, merge_identical_images


class DatasetIntegrityTest(unittest.TestCase):
    def fixture(self,root,folder,name,task_name,class_id=1,invalid=False):
        source=root/folder
        (source/'File1/ann').mkdir(parents=True)
        (source/'File1/img').mkdir(parents=True)
        (source/'meta.json').write_text(json.dumps({'classes':[{'title':task_name,'id':class_id}]}))
        image=Image.fromarray(np.random.default_rng(1).integers(0,255,(128,128,3),dtype=np.uint8))
        image.save(source/'File1/img'/name)
        annotation={'size':{'width':128,'height':128},'objects':[{
            'classTitle':task_name,'classId':class_id,'geometryType':'polygon','labelerLogin':'human',
            'points':{'exterior':[[10,10],[60,10],[60,60],[10,60]] if not invalid else [[10,10],[10,20],[10,30]],'interior':[]}}]}
        (source/'File1/ann'/(name+'.json')).write_text(json.dumps(annotation))

    def test_semantics_come_from_content_and_exact_duplicates_join_both_tasks(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/'raw';output=Path(temp)/'coco'
            self.fixture(root,'misleading parts folder','same.png','Scratch')
            self.fixture(root,'misleading damages folder','same.png','Front-bumper',2)
            before={str(p.relative_to(root)):p.read_bytes() for p in root.rglob('*') if p.is_file()}
            report=convert(root,output)
            self.assertEqual((2,1,1),(report['source_images'],report['images'],report['paired_task_images']))
            self.assertEqual(2,report['annotations'])
            all_images=[r for split in ('train','val','test') for r in json.loads((output/f'{split}.json').read_text())['images']]
            self.assertEqual(['damage','part'],all_images[0]['tasks'])
            self.assertEqual(before,{str(p.relative_to(root)):p.read_bytes() for p in root.rglob('*') if p.is_file()})
            first={p.name:p.read_bytes() for p in output.glob('*.json')}
            convert(root,output)
            self.assertEqual(first,{p.name:p.read_bytes() for p in output.glob('*.json')})

    def test_invalid_image_stops_by_default_and_requires_explicit_quarantine(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/'raw';output=Path(temp)/'coco'
            self.fixture(root,'source','broken.png','Scratch',invalid=True)
            self.fixture(root,'other','valid.png','Front-bumper',2)
            with self.assertRaises(ValueError):
                convert(root,output)
            report=convert(root,output,quarantine=True)
            self.assertEqual(1,report['quarantined_images'])
            self.assertIn('Degenerate',report['errors'][0]['error'])

    def test_holes_preserved_and_box_coordinates_not_scaled_or_guessed(self):
        obj={'geometryType':'polygon','points':{'exterior':[[1,2],[20,2],[20,30],[1,30]],
             'interior':[[[5,5],[10,5],[10,10],[5,10]]]}}
        box,area,segmentation=polygon(obj,40,40)
        self.assertEqual([1,2,19,28],box)
        self.assertLess(area,20*29)
        self.assertEqual(1600,sum(segmentation['counts']))
        self.assertEqual([40,40],segmentation['size'])

    def test_perceptual_groups_never_cross_splits_and_seed_is_repeatable(self):
        rows=[{'id':i,'pixel_sha256':str(i),'dhash':i*99991,'labels':['Scratch']} for i in range(40)]
        rows[1]['dhash']=rows[0]['dhash']
        first=copy.deepcopy(rows);second=copy.deepcopy(rows)
        split_groups(group_images(first),17);split_groups(group_images(second),17)
        self.assertEqual(first,second)
        self.assertEqual(first[0]['split'],first[1]['split'])


class UnifiedInferenceTest(unittest.TestCase):
    def test_bad_or_oversized_images_rejected_without_codec_installation(self):
        for content in (b'',b'not an image',b'\x00'*50):
            with self.assertRaises(ValueError):
                decode_image(content)
        buf=BytesIO();Image.new('RGB',(200,100)).save(buf,'PNG')
        with patch('app.vision.processing.MAX_PIXELS',100):
            with self.assertRaises(ValueError):
                decode_image(buf.getvalue())

    def test_preprocessing_and_model_score_coordinate_contract(self):
        image=Image.new('RGB',(200,100),(10,20,30))
        pixels,ratio=preprocess(image,416)
        self.assertEqual((3,416,416),pixels.shape)
        self.assertEqual([30,20,10],pixels[:,0,0].tolist())
        category={'id':8,'name':'Scratch','code':'SCRATCH','task':'damage'}
        prediction=np.array([[[208,104,100,50,.8,.5]]],dtype=np.float32)
        results=postprocess(prediction,[category],ratio,200,100)
        self.assertAlmostEqual(.4,results[0]['confidence'],places=6)
        self.assertAlmostEqual((208-50)/ratio,results[0]['boundingBox']['x1'],places=5)

    def test_ambiguous_parts_remain_unknown(self):
        damage={'boundingBox':dict(zip(('x1','y1','x2','y2'),(20,20,40,40)))}
        def part(code):
            return {'code':code,'confidence':.9,'boundingBox':dict(zip(('x1','y1','x2','y2'),(0,0,100,100)))}
        self.assertEqual([],match_parts(damage,[part('HOOD'),part('FRONT_BUMPER')]))
        self.assertEqual(['HOOD'],match_parts(damage,[part('HOOD')]))

    def test_default_and_unapproved_bundle_fail_closed(self):
        runtime=UnifiedVisionRuntime()
        with patch.dict('os.environ',{'DAMAGE_ANALYSIS_ENABLED':'false'}):
            with self.assertRaises(VisionUnavailable):runtime.require_available()
        with tempfile.TemporaryDirectory() as temp:
            Path(temp,'manifest.json').write_text(json.dumps({'schema_version':'hitl-v1','production_approved':False}))
            with patch.dict('os.environ',{'DAMAGE_ANALYSIS_ENABLED':'true','DAMAGE_MODEL_BUNDLE':temp}):
                with self.assertRaises(VisionUnavailable):runtime.require_available()

    def test_empty_predictions_are_inconclusive_and_do_not_invent_confidence(self):
        runtime=UnifiedVisionRuntime()
        runtime.manifest={'input_size':416,'threshold':.25,'nms_threshold':.45,'model_version':'unit-test'}
        runtime.categories={t:[{'id':i+1,'name':'Scratch' if t=='damage' else 'Hood','task':t,'code':'SCRATCH' if t=='damage' else 'HOOD'}] for i,t in enumerate(('damage','part'))}
        class Session:
            def run(self,*args):return [np.zeros((1,1,6),dtype=np.float32)]*2
        image=Image.fromarray(np.random.default_rng(2).integers(0,255,(200,200,3),dtype=np.uint8))
        buf=BytesIO();image.save(buf,'PNG')
        with patch.object(runtime,'require_available'),patch.object(runtime,'_load',return_value=Session()):
            result=runtime.analyze(buf.getvalue())
        self.assertEqual('INCONCLUSIVE',result['analysisOutcome'])
        self.assertEqual('UNKNOWN',result['damageSeverity'])
        self.assertIsNone(result['confidenceScore'])
        self.assertEqual([],result['damageTypes'])

    def test_lazy_session_is_constructed_once_and_tampered_bundle_fails_closed(self):
        from concurrent.futures import ThreadPoolExecutor
        import hashlib
        import sys
        import types
        import time
        constructed=[]
        class Options:pass
        class Session:
            def __init__(self,*args,**kwargs):
                time.sleep(.01);constructed.append(self)
            def get_outputs(self):
                return [types.SimpleNamespace(name='damage',shape=[1,3549,13]),
                        types.SimpleNamespace(name='part',shape=[1,3549,26])]
            def get_inputs(self):
                return [types.SimpleNamespace(name='images',type='tensor(float)',shape=[1,3,416,416])]
        with tempfile.TemporaryDirectory() as temp:
            directory=Path(temp)
            catalog=(Path(__file__).resolve().parents[1]/'app/vision/classes.json').read_bytes()
            (directory/'classes.json').write_bytes(catalog)
            (directory/'model.onnx').write_bytes(b'unit-fixture')
            (directory/'manifest.json').write_text(json.dumps({'schema_version':'hitl-v1',
                'production_approved':True,'input_size':416,'input_color':'BGR','outputs':['damage','part'],
                'threshold':.25,'nms_threshold':.45,'model_sha256':hashlib.sha256(b'unit-fixture').hexdigest(),
                'catalog_sha256':hashlib.sha256(catalog).hexdigest()}))
            runtime=UnifiedVisionRuntime()
            with patch.dict('os.environ',{'DAMAGE_ANALYSIS_ENABLED':'true','DAMAGE_MODEL_BUNDLE':temp}),patch.dict(sys.modules,{'onnxruntime':types.SimpleNamespace(SessionOptions=Options,InferenceSession=Session)}):
                with ThreadPoolExecutor(max_workers=8) as executor:
                    sessions=list(executor.map(lambda _:runtime._load(),range(16)))
                self.assertEqual(1,len(constructed))
                self.assertTrue(all(s is constructed[0] for s in sessions))
                self.assertEqual('READY',runtime.status())
                (directory/'model.onnx').write_bytes(b'modified-model')
                with self.assertRaises(VisionUnavailable):runtime.require_available()
                self.assertEqual('UNAVAILABLE',runtime.status())


class PartialLabelGradientTest(unittest.TestCase):
    def test_inactive_head_has_no_gradients_or_batchnorm_updates(self):
        import torch
        from ml.model import UnifiedYOLOXTiny
        torch.set_num_threads(2);torch.manual_seed(3)
        model=UnifiedYOLOXTiny().train()
        part_buffers={n:b.clone() for n,b in model.heads['part'].named_buffers()}
        targets={'damage':torch.tensor([[[0,64,64,32,32]]]*2,dtype=torch.float32),
                 'part':torch.full((2,1,5),float('nan'))}
        losses=model(torch.rand(2,3,128,128)*255,targets,torch.tensor([[True,False]]*2))
        sum(losses.values()).backward()
        self.assertTrue(all(p.grad is None for p in model.heads['part'].parameters()))
        self.assertTrue(any(p.grad is not None for p in model.heads['damage'].parameters()))
        for name,buffer in model.heads['part'].named_buffers():
            self.assertTrue(torch.equal(buffer,part_buffers[name]))
        self.assertTrue(all(torch.isfinite(p.grad).all() for p in model.parameters() if p.grad is not None))


class VisionApiContractTest(unittest.IsolatedAsyncioTestCase):
    async def test_enabled_multipart_route_serializes_the_versioned_unknown_repair_contract(self):
        import main
        from app.vision import api
        payload={
            'schemaVersion':'hitl-v1','modelVersion':'contract-fixture','analysisOutcome':'DAMAGE_DETECTED',
            'imageWidth':128,'imageHeight':128,'damageSeverity':'UNKNOWN','confidenceScore':.8,
            'damageTypes':['SCRATCH'],'affectedParts':[],
            'detections':[{'classId':8,'code':'SCRATCH','label':'Scratch','task':'damage','confidence':.8,
                'boundingBox':{'x1':10,'y1':10,'x2':30,'y2':40},'affectedPart':'UNKNOWN'}],
            'partDetections':[], 'repairRecommendations':[{'damageType':'SCRATCH',
                'recommendedAction':'PROFESSIONAL_INSPECTION','partReplacementRequired':None,'affectedParts':[]}],
            'analysisMessage':'Fiziksel inceleme gerekir.'}
        buf=BytesIO();Image.new('RGB',(128,128)).save(buf,'PNG')
        body=(b'--contract\r\nContent-Disposition: form-data; name="image"; filename="car.png"\r\n'
              b'Content-Type: image/png\r\n\r\n'+buf.getvalue()+b'\r\n--contract--\r\n')
        sent=[];consumed=False
        async def receive():
            nonlocal consumed
            if consumed:return {'type':'http.disconnect'}
            consumed=True
            return {'type':'http.request','body':body,'more_body':False}
        async def send(message):sent.append(message)
        key=b'contract-service-key-at-least-32-characters'
        with patch.dict('os.environ',{'AI_SERVICE_API_KEY':key.decode()}),patch.object(api.runtime,'require_available'),patch.object(api.runtime,'analyze',return_value=payload) as analysis:
            app=main.app.build_middleware_stack()
            await app({'type':'http','asgi':{'version':'3.0'},'http_version':'1.1','method':'POST',
                'scheme':'http','path':'/api/v1/analyze','root_path':'','query_string':b'',
                'headers':[(b'x-ai-service-key',key),(b'content-type',b'multipart/form-data; boundary=contract')],
                'server':('test',80),'client':('127.0.0.1',1234)},receive,send)
        self.assertEqual(200,next(m['status'] for m in sent if m['type']=='http.response.start'))
        result=json.loads(b''.join(m.get('body',b'') for m in sent if m['type']=='http.response.body'))
        self.assertEqual('Scratch',result['detections'][0]['label'])
        self.assertIsNone(result['repairRecommendations'][0]['partReplacementRequired'])
        self.assertEqual('UNKNOWN',result['damageSeverity'])
        analysis.assert_called_once_with(buf.getvalue(),None)


class OnnxExportContractTest(unittest.TestCase):
    def test_two_heads_export_with_real_cpu_parity_and_stay_unapproved(self):
        import importlib.util
        if importlib.util.find_spec('onnx') is None or importlib.util.find_spec('onnxruntime') is None:
            self.skipTest('Install requirements-training.txt for ONNX export regression')
        import torch
        from ml.model import UnifiedYOLOXTiny
        from ml.export import export
        torch.manual_seed(4);torch.set_num_threads(2)
        catalog=json.loads((Path(__file__).resolve().parents[1]/'app/vision/classes.json').read_text(encoding='utf-8'))
        with tempfile.TemporaryDirectory() as temporary:
            directory=Path(temporary);checkpoint=directory/'fixture.pth'
            torch.save({'schema_version':'hitl-v1','model':UnifiedYOLOXTiny().state_dict(),
                'catalog':catalog,'epoch':0,'pretrained':None,
                'training_data_sha256':'unit-training','validation_data_sha256':'unit-validation'},checkpoint)
            image=directory/'fixture.png';Image.new('RGB',(256,200),(100,120,140)).save(image)
            output=directory/'bundle'
            export(checkpoint,output,image,size=416,repeats=1)
            manifest=json.loads((output/'manifest.json').read_text())
            parity=json.loads((output/'benchmark.json').read_text())
            self.assertFalse(manifest['production_approved'])
            self.assertEqual([1,3549,13],parity['parity']['damage']['shape'])
            self.assertEqual([1,3549,26],parity['parity']['part']['shape'])
            self.assertTrue((output/'LICENSE.YOLOX').is_file())
