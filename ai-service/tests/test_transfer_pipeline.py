import importlib.util
import hashlib
from io import BytesIO
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

from app.vision.rfdetr_processing import preprocess_rfdetr, postprocess_rfdetr
from app.vision.rtdetr_processing import preprocess_rtdetr
from app.vision.runtime import UnifiedVisionRuntime, VisionUnavailable
from ml.metrics import operating_point, score, calibrate
from ml.prepare_transfer import prepare
from ml.signatures import split_signature


class TransferPipelineTest(unittest.TestCase):
    categories = [{'id': 1, 'name': 'Scratch', 'code': 'SCRATCH', 'task': 'damage', 'task_index': 0},
                  {'id': 2, 'name': 'Dent', 'code': 'DENT', 'task': 'damage', 'task_index': 1}]

    def test_portable_split_identity_accepts_relocation_but_not_label_changes(self):
        first = {'info': {'source_root': 'C:/old/path'}, 'images': [{'id': 1, 'sha256': 'image-hash'}],
                 'annotations': [{'category_id': 1, 'bbox': [1, 2, 3, 4]}]}
        relocated = dict(first, info={'source_root': '/new/path'})
        self.assertEqual(split_signature(first), split_signature(relocated))
        changed = dict(relocated, annotations=[{'category_id': 2, 'bbox': [1, 2, 3, 4]}])
        self.assertNotEqual(split_signature(first), split_signature(changed))

    def test_rgb_square_normalization_preserves_color_order_and_non_square_dimensions(self):
        image = Image.new('RGB', (19, 7), (255, 0, 128))
        result = preprocess_rfdetr(image, 32)
        expected = (np.array([1, 0, 128/255])-np.array([.485, .456, .406]))/np.array([.229, .224, .225])
        self.assertEqual((3, 32, 32), result.shape)
        np.testing.assert_allclose(result[:, 20, 30], expected, atol=1e-6)
        self.assertTrue(result.flags.c_contiguous)

    @unittest.skipUnless(importlib.util.find_spec('torchvision'), 'Offline transfer environment supplies torchvision')
    def test_numpy_preprocessing_matches_publisher_torchvision_resize_without_antialias(self):
        import torchvision.transforms.functional as F
        image = Image.fromarray(np.random.default_rng(10).integers(0, 256, (71, 113, 3), dtype=np.uint8))
        actual = preprocess_rfdetr(image, 64)
        expected = F.normalize(F.resize(F.to_tensor(image), [64, 64], antialias=False), [.485, .456, .406], [.229, .224, .225]).numpy()
        np.testing.assert_allclose(actual, expected, atol=2e-5, rtol=2e-5)

    @unittest.skipUnless(importlib.util.find_spec('torchvision'), 'Offline transfer environment supplies torchvision')
    def test_pil_antialias_path_matches_framework_validation_transform(self):
        import torchvision.transforms.functional as F
        image = Image.fromarray(np.random.default_rng(10).integers(0, 256, (71, 113, 3), dtype=np.uint8))
        expected = F.normalize(F.to_tensor(F.resize(image, [64, 64])), [.485, .456, .406], [.229, .224, .225]).numpy()
        np.testing.assert_allclose(preprocess_rfdetr(image, 64, antialias=True), expected, atol=1e-6)

    def test_set_decoder_uses_sigmoid_scores_source_identity_and_independent_axis_scaling(self):
        boxes = np.array([[[.5, .5, .5, .5]]], np.float32)
        logits = np.array([[[2., -3., 10.]]], np.float32)
        result = postprocess_rfdetr(boxes, logits, self.categories, 200, 100)
        self.assertEqual(1, len(result))
        self.assertEqual('Scratch', result[0]['label'])
        self.assertAlmostEqual(1/(1+np.exp(-2.)), result[0]['confidence'], places=6)
        self.assertEqual({'x1': 50., 'y1': 25., 'x2': 150., 'y2': 75.}, result[0]['boundingBox'])
        with self.assertRaises(ValueError):
            postprocess_rfdetr(boxes, logits[:, :, :2], self.categories, 200, 100)

    def test_set_decoder_respects_existing_backend_limit_of_100_detections(self):
        boxes = np.tile(np.array([.5, .5, .2, .2], np.float32), (1, 200, 1))
        logits = np.full((1, 200, 3), -30, dtype=np.float32)
        logits[0, :, 0] = 3
        self.assertEqual(100, len(postprocess_rfdetr(boxes, logits, self.categories, 400, 200)))

    def test_rtdetr_last_damage_class_is_not_discarded_as_background(self):
        boxes = np.array([[[.5,.5,.2,.2]]],np.float32)
        logits = np.array([[[-30,3]]],np.float32)
        result = postprocess_rfdetr(boxes,logits,self.categories,200,100,background_class=False)
        self.assertEqual(['Dent'],[item['label'] for item in result])

    def test_rtdetr_rgb_rescaling_has_no_imagenet_normalization(self):
        actual = preprocess_rtdetr(Image.new('RGB',(19,7),(255,0,128)),32)
        self.assertEqual((3,32,32),actual.shape)
        self.assertTrue(actual.flags.c_contiguous)
        np.testing.assert_allclose(actual[:,10,10],[1,0,128/255],atol=1e-7)

    @unittest.skipUnless(importlib.util.find_spec('transformers'),'Offline transfer environment supplies Transformers')
    def test_rtdetr_preprocessing_matches_the_official_portable_pil_processor(self):
        try:
            from transformers.models.rt_detr.image_processing_pil_rt_detr import RTDetrImageProcessorPil
        except ImportError:
            self.skipTest('Reviewed transfer environment supplies the portable processor')
        image = Image.fromarray(np.random.default_rng(2026).integers(0,256,(419,637,3),dtype=np.uint8))
        expected = RTDetrImageProcessorPil(size={'height':640,'width':640},do_normalize=False)(images=image,return_tensors='np')['pixel_values'][0]
        np.testing.assert_allclose(preprocess_rtdetr(image),expected,atol=1e-7,rtol=1e-6)

    def test_operating_point_matching_is_class_aware_and_duplicate_predictions_are_false_positives(self):
        annotations = [{'image_id': 1, 'category_id': 1, 'bbox': [0, 0, 10, 10]},
                       {'image_id': 1, 'category_id': 2, 'bbox': [0, 0, 10, 10]}]
        predictions = [dict(a, score=.9) for a in annotations]+[dict(annotations[0], score=.8)]
        result = operating_point(annotations, predictions, self.categories)
        self.assertEqual((2, 1, 0), tuple(result[k] for k in ('true_positive', 'false_positive', 'false_negative')))

    @unittest.skipUnless(importlib.util.find_spec('pycocotools'),'Offline evaluation environment supplies pycocotools')
    def test_empty_predictions_score_zero_and_do_not_manufacture_a_feasible_threshold(self):
        document = {'categories': self.categories, 'images': [{'id': 1, 'tasks': ['damage'], 'width': 20, 'height': 20}],
                    'annotations': [{'id': 1, 'image_id': 1, 'category_id': 1, 'bbox': [0, 0, 10, 10], 'area': 100, 'iscrowd': 0}]}
        result = score(document, 'damage', [])
        self.assertEqual(0, result['mAP50_95'])
        self.assertEqual(0, result['recall'])
        self.assertIsNone(result['negative_only_fpr'])
        self.assertFalse(calibrate(document, 'damage', [])['constraint_satisfied'])

    def test_threshold_calibration_never_uses_unannotated_task_images_as_negatives(self):
        document = {'categories': self.categories, 'images': [{'id': 1, 'tasks': ['damage']}, {'id': 2, 'tasks': ['part']}],
                    'annotations': [{'image_id': 1, 'category_id': 1, 'bbox': [0, 0, 10, 10]}]}
        result = calibrate(document, 'damage', [{'image_id': 2, 'category_id': 1, 'bbox': [0, 0, 10, 10], 'score': .99}])
        self.assertEqual(0, result['selected']['false_positive'])

    @unittest.skipUnless(importlib.util.find_spec('pycocotools'),'Offline evaluation environment supplies pycocotools')
    def test_segmentation_metrics_use_mask_iou_instead_of_box_iou(self):
        from pycocotools import mask as mask_utils
        truth = np.zeros((20, 20), dtype=np.uint8)
        truth[:10, :10] = 1
        predicted = np.zeros_like(truth)
        predicted[10:, 10:] = 1
        def encoded(array):
            result = mask_utils.encode(np.asfortranarray(array))
            result['counts'] = result['counts'].decode('ascii')
            return result
        document = {'categories': self.categories, 'images': [{'id': 1, 'tasks': ['damage'], 'width': 20, 'height': 20}],
                    'annotations': [{'id': 1, 'image_id': 1, 'category_id': 1, 'bbox': [0, 0, 10, 10],
                                     'area': 100, 'iscrowd': 0, 'segmentation': encoded(truth)}]}
        predictions = [{'image_id': 1, 'category_id': 1, 'bbox': [0, 0, 10, 10], 'score': .9, 'segmentation': encoded(predicted)}]
        self.assertEqual(0, score(document, 'damage', predictions, iou_type='segm')['recall'])

    def fixture(self, root, leak=False):
        data = root/'source'
        data.mkdir()
        for index, split in enumerate(('train', 'val', 'test')):
            Image.new('RGB', (20, 20), (index*70, 20, 10)).save(data/f'{split}.png')
            doc = {'info': {'source_root': str(data)}, 'categories': self.categories,
                   'images': [{'id': index+1, 'file_name': f'{split}.png', 'tasks': ['damage'], 'width': 20, 'height': 20,
                               'group_id': 1 if leak else index+1}],
                   'annotations': [{'id': index+1, 'image_id': index+1, 'category_id': 1, 'bbox': [1, 1, 10, 10],
                                    'area': 100, 'iscrowd': 0, 'segmentation': {'size': [20, 20], 'counts': [400]}}]}
            (data/f'{split}.json').write_text(json.dumps(doc), encoding='utf-8')
        return data

    @unittest.skipUnless(importlib.util.find_spec('pycocotools'),'Offline evaluation environment supplies pycocotools')
    def test_training_view_omits_test_preserves_sources_and_remaps_ids(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = self.fixture(root)
            before = {p.name: p.read_bytes() for p in data.iterdir()}
            result = prepare(data, root/'view')
            self.assertFalse(result['test_exposed_to_training'])
            self.assertFalse((root/'view/test').exists())
            doc = json.loads((root/'view/train/_annotations.coco.json').read_text())
            self.assertEqual(0, doc['annotations'][0]['category_id'])
            self.assertEqual(before, {p.name: p.read_bytes() for p in data.iterdir()})
            with self.assertRaises(ValueError):
                prepare(data, root/'view')

    @unittest.skipUnless(importlib.util.find_spec('pycocotools'),'Offline evaluation environment supplies pycocotools')
    def test_training_view_rejects_cross_split_groups(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaises(ValueError):
                prepare(self.fixture(root, leak=True), root/'view')


@unittest.skipUnless(importlib.util.find_spec('onnx'), 'Offline export environment supplies onnx')
class EnsembleContractTest(unittest.TestCase):
    def bundle(self, root, family='rfdetr'):
        import onnx
        from onnx import helper, numpy_helper, TensorProto
        catalog_path = Path(__file__).resolve().parents[1]/'app/vision/classes.json'
        catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
        (root/'classes.json').write_bytes(catalog_path.read_bytes())
        boxes = np.full((1, 300, 4), .2, dtype=np.float32)
        boxes[0, 0] = [.5, .5, .2, .2]
        logits = np.full((1, 300, 8 if family=='rtdetr' else 9), -30, dtype=np.float32)
        logits[0, 0, 7] = 3
        parts = np.zeros((1, 1, 26), dtype=np.float32)
        parts[0, 0, :5] = [208, 104, 208, 166.4, 1]
        hood = next(c for c in catalog['categories'] if c['name'] == 'Hood')
        parts[0, 0, 5+hood['task_index']] = .9
        damage_size=640 if family=='rtdetr' else 384
        for filename, size, outputs in [('damage.onnx', damage_size, {'boxes': boxes, 'logits': logits}), ('part.onnx', 416, {'part': parts})]:
            nodes = [helper.make_node('Constant', [], [name], value=numpy_helper.from_array(value)) for name, value in outputs.items()]
            graph = helper.make_graph(nodes, filename, [helper.make_tensor_value_info('images', TensorProto.FLOAT, [1, 3, size, size])],
                                      [helper.make_tensor_value_info(name, TensorProto.FLOAT, list(value.shape)) for name, value in outputs.items()])
            onnx.save(helper.make_model(graph, opset_imports=[helper.make_opsetid('', 17)], ir_version=10), root/filename)
        manifest = {'format': 'ensemble-v1', 'schema_version': 'hitl-v1', 'production_approved': True,
                    'model_version': 'synthetic-test-only', 'input_sizes': {'damage': damage_size, 'part': 416},
                    'outputs': ['boxes', 'logits', 'part'], 'num_select': 300, 'num_queries': 300,
                    'damage_preprocessing': 'RGB-square-bilinear-no-antialias-ImageNet-v1',
                    'part_preprocessing': 'BGR-letterbox-114-v1', 'threshold': .25, 'part_threshold': .25, 'nms_threshold': .45}
        if family=='rtdetr':
            manifest.update(damage_family=family,damage_preprocessing='RGB-square-PIL-bilinear-rescale01-v1')
        for filename, key in [('damage.onnx', 'damage_sha256'), ('part.onnx', 'part_sha256'), ('classes.json', 'catalog_sha256')]:
            manifest[key] = hashlib.sha256((root/filename).read_bytes()).hexdigest()
        (root/'manifest.json').write_text(json.dumps(manifest))
        return manifest

    def test_actual_onnx_ensemble_preserves_api_identity_coordinates_and_unknown_repair(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.bundle(root)
            with patch.dict('os.environ', {'DAMAGE_ANALYSIS_ENABLED': 'true', 'DAMAGE_MODEL_BUNDLE': str(root)}):
                runtime = UnifiedVisionRuntime()
                pixels = np.random.default_rng(22).integers(80, 200, (200, 400, 3), dtype=np.uint8)
                buf = BytesIO()
                Image.fromarray(pixels).save(buf, 'PNG')
                result = runtime.analyze(buf.getvalue())
                self.assertEqual('hitl-v1', result['schemaVersion'])
                self.assertEqual('Scratch', result['detections'][0]['label'])
                self.assertEqual('HOOD', result['detections'][0]['affectedPart'])
                self.assertAlmostEqual(160, result['detections'][0]['boundingBox']['x1'], places=4)
                self.assertEqual('UNKNOWN', result['damageSeverity'])
                self.assertIsNone(result['repairRecommendations'][0]['partReplacementRequired'])
                self.assertNotIn('_query', result['detections'][0])

    def test_approval_flag_and_each_component_checksum_are_required(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            manifest = self.bundle(root)
            with patch.dict('os.environ', {'DAMAGE_ANALYSIS_ENABLED': 'true', 'DAMAGE_MODEL_BUNDLE': str(root)}):
                manifest['production_approved'] = False
                (root/'manifest.json').write_text(json.dumps(manifest))
                with self.assertRaises(VisionUnavailable):
                    UnifiedVisionRuntime().require_available()
                manifest['production_approved'] = True
                (root/'manifest.json').write_text(json.dumps(manifest))
                (root/'part.onnx').write_bytes(b'tampered')
                with self.assertRaises(VisionUnavailable):
                    UnifiedVisionRuntime().require_available()

    def test_rtdetr_onnx_contract_preserves_last_class_and_rejects_wrong_normalization_or_smoke(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            manifest=self.bundle(root,family='rtdetr')
            with patch.dict('os.environ',{'DAMAGE_ANALYSIS_ENABLED':'true','DAMAGE_MODEL_BUNDLE':str(root)}):
                pixels=np.random.default_rng(22).integers(80,200,(200,400,3),dtype=np.uint8)
                image=BytesIO()
                Image.fromarray(pixels).save(image,'PNG')
                result=UnifiedVisionRuntime().analyze(image.getvalue())
                self.assertEqual('Scratch',result['detections'][0]['label'])
                self.assertEqual(8,result['detections'][0]['classId'])
                self.assertEqual('UNKNOWN',result['damageSeverity'])
                manifest['damage_preprocessing']='RGB-square-PIL-bilinear-ImageNet-v1'
                (root/'manifest.json').write_text(json.dumps(manifest))
                with self.assertRaises(VisionUnavailable):
                    UnifiedVisionRuntime().require_available()
                manifest['damage_preprocessing']='RGB-square-PIL-bilinear-rescale01-v1'
                manifest['export_smoke_only']=True
                (root/'manifest.json').write_text(json.dumps(manifest))
                with self.assertRaises(VisionUnavailable):
                    UnifiedVisionRuntime().require_available()

    def test_malformed_manifest_or_graph_is_unavailable_before_analysis(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            manifest=self.bundle(root)
            with patch.dict('os.environ',{'DAMAGE_ANALYSIS_ENABLED':'true','DAMAGE_MODEL_BUNDLE':str(root)}):
                manifest['damage_family']=[]
                (root/'manifest.json').write_text(json.dumps(manifest))
                with self.assertRaises(VisionUnavailable):
                    UnifiedVisionRuntime().require_available()
                manifest['damage_family']='rfdetr'
                (root/'damage.onnx').write_bytes(b'invalid-onnx-graph')
                manifest['damage_sha256']=hashlib.sha256((root/'damage.onnx').read_bytes()).hexdigest()
                (root/'manifest.json').write_text(json.dumps(manifest))
                with self.assertRaises(VisionUnavailable):
                    UnifiedVisionRuntime().require_available()


if __name__ == '__main__':
    unittest.main()
