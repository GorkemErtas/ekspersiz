import argparse
from contextlib import redirect_stdout
from io import StringIO
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image
import yaml

from experiments.config import validate_dataset_config
from experiments.roboflow_dataset import (MAPPING, SPLITS, mapping, polygon_box, sha256,
                                           source_manifest, validate_experiment, write_json)
from experiments.roboflow_metrics import metric_report
from scripts.import_roboflow_damage_dataset import import_dataset
from scripts.train_roboflow_damage_model import train
from scripts import train_roboflow_damage_model as runner
from scripts import evaluate_roboflow_damage_model as evaluator


class PolygonTest(unittest.TestCase):
    def test_triangle_and_closed_polygon_produce_enclosing_box(self):
        for line in ('3 .1 .2 .9 .2 .5 .8', '3 .1 .2 .9 .2 .5 .8 .1 .2'):
            cid, box, points = polygon_box(line, 11)
            self.assertEqual(3, cid)
            np.testing.assert_allclose(box, [.5, .5, .8, .6])
            self.assertEqual(3, len(points))

    def test_bad_polygons_fail_without_silent_clipping_or_dropped_class(self):
        for line in ('0 .5 .5 .2 .2', '11 0 0 1 0 1 1', '-1 0 0 1 0 1 1',
                     '0 nan 0 1 0 1 1', '0 -.01 0 1 0 1 1', '0 0 0 1.01 0 1 1',
                     '0 0 0 .5 .5 1 1', '0 0 0 1 1 0 1 1 0', '0 0 0 1 0 1 1 1 0'):
            with self.subTest(line=line), self.assertRaises(ValueError):
                polygon_box(line, 11)


class ImportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root/'source'
        self.source.mkdir()
        self.target = self.root/'target'
        config = {s: f'../{folder}/images' for s, folder in SPLITS.items()}
        config.update(nc=11, names=mapping()['source_names'], roboflow={'license': 'CC BY 4.0'})
        (self.source/'data.yaml').write_text(yaml.safe_dump(config), encoding='utf-8')
        rng = np.random.default_rng(42)
        for split, folder in SPLITS.items():
            (self.source/folder/'images').mkdir(parents=True)
            (self.source/folder/'labels').mkdir()
            for cid in range(11):
                Image.fromarray(rng.integers(0, 256, (48, 64, 3), dtype=np.uint8)).save(self.source/folder/'images'/f'{cid}.png')
                (self.source/folder/'labels'/f'{cid}.txt').write_text(f'{cid} .1 .2 .9 .2 .5 .8\n', encoding='utf-8')

    def do_import(self, **kwargs):
        with redirect_stdout(StringIO()):
            return import_dataset(self.source, self.target, **kwargs)

    def approved_review(self, report):
        review = json.loads((self.target/'review.json').read_text(encoding='utf-8'))
        for key in ('annotations_accepted', 'quarantine_accepted', 'negative_images_checked', 'imbalance_accepted', 'provenance_reviewed_for_research'):
            review[key] = True
        review.update(reviewer='unit-test fixture only', reviewed_at='2026-10-23', reviewed_samples=report['review_samples'])
        write_json(self.target/'review.json', review)

    def test_all_classes_ids_source_bytes_and_split_membership_preserved(self):
        original = source_manifest(self.source)
        report = self.do_import()
        self.assertEqual(original, source_manifest(self.source))
        self.assertEqual(11, len(report['class_counts']['train']))
        for split, folder in SPLITS.items():
            self.assertEqual(11, report['images'][split]['imported'])
            for cid in range(11):
                self.assertEqual(sha256(self.source/folder/'images'/f'{cid}.png'), sha256(self.target/'images'/split/f'{cid}.png'))
                self.assertEqual(str(cid), (self.target/'labels'/split/f'{cid}.txt').read_text().split()[0])
                self.assertEqual((self.source/folder/'labels'/f'{cid}.txt').read_bytes(),
                                 (self.target/'source-segmentation'/split/f'{cid}.txt').read_bytes())
        # Production taxonomy still refuses this dataset.
        with self.assertRaisesRegex(ValueError, 'outside the canonical'):
            validate_dataset_config(self.target/'data.yaml')
        with self.assertRaises(ValueError):
            self.do_import()

    def test_one_bad_polygon_quarantines_entire_multilabel_image(self):
        label = self.source/'train/labels/0.txt'
        label.write_text(label.read_text() + '5 0 0 1 1 0 1 1 0\n')
        (self.source/'valid/labels/1.txt').unlink()
        (self.source/'test/labels/orphan.txt').write_text('0 .1 .2 .9 .2 .5 .8')
        report = self.do_import()
        self.assertEqual(1, report['images']['train']['quarantined'])
        self.assertEqual(1, report['images']['val']['quarantined'])
        self.assertFalse((self.target/'images/train/0.png').exists())
        self.assertEqual(1, len(report['orphan_labels']))

    def test_bijective_mapping_cannot_drop_or_merge_a_class(self):
        config = mapping()
        config['model_names'][0] = config['model_names'][1]
        path = self.root/'bad-mapping.yaml'
        path.write_text(yaml.safe_dump(config))
        with self.assertRaisesRegex(ValueError, 'one-to-one'):
            self.do_import(mapping_path=path)
        self.assertFalse(self.target.exists())

    def test_exact_leakage_is_quarantined_on_both_sides_without_reassigning_splits(self):
        (self.source/'test/images/0.png').write_bytes((self.source/'train/images/0.png').read_bytes())
        report = self.do_import()
        self.assertTrue(any(p['kind']=='exact' and p['cross_split'] for p in report['duplicate_pairs']))
        self.assertFalse((self.target/'images/train/0.png').exists())
        self.assertFalse((self.target/'images/test/0.png').exists())
        self.assertTrue((self.source/'train/images/0.png').exists())
        self.assertTrue((self.source/'test/images/0.png').exists())
        self.assertFalse(any(p['kind']=='exact' and p['cross_split'] and p['both_imported'] for p in report['duplicate_pairs']))

    def test_unresolved_near_duplicate_cannot_be_approved_with_a_generic_checkbox(self):
        with Image.open(self.source/'train/images/0.png') as image:
            copy = image.copy()
        pixel = copy.getpixel((0, 0))
        copy.putpixel((0, 0), ((pixel[0]+1)%256, pixel[1], pixel[2]))
        copy.save(self.source/'test/images/0.png')
        report = self.do_import()
        self.assertTrue(any(p['kind']=='near_candidate' and p['cross_split'] and p['both_imported'] for p in report['duplicate_pairs']))
        self.approved_review(report)
        with self.assertRaisesRegex(ValueError, 'Unresolved cross-split'):
            validate_experiment(self.target/'data.yaml', review=self.target/'review.json')

    def test_review_and_fingerprint_gate_precedes_any_training(self):
        report = self.do_import()
        with self.assertRaisesRegex(ValueError, 'visual review'):
            train(argparse.Namespace(data=self.target/'data.yaml', review=None, check_only=True))
        self.approved_review(report)
        self.assertEqual(33, validate_experiment(self.target/'data.yaml', review=self.target/'review.json')['total_images'])
        (self.target/'labels/train/0.txt').write_text('0 .5 .5 .2 .2\n')
        with self.assertRaisesRegex(ValueError, 'changed'):
            validate_experiment(self.target/'data.yaml', review=self.target/'review.json')

    def test_repeat_import_is_content_reproducible(self):
        first = self.do_import()
        first_report_hash = sha256(self.target/'import-report.json')
        self.target = self.root/'second-target'
        second = self.do_import()
        self.assertEqual(first['output_manifest'], second['output_manifest'])
        self.assertEqual(first_report_hash, sha256(self.target/'import-report.json'))

    def test_training_arguments_and_provenance_are_written_without_running_a_gpu(self):
        from unittest.mock import Mock
        import types
        report = self.do_import()
        self.approved_review(report)
        weights = self.root/'fixture-yolo11s.pt'
        weights.write_bytes(b'test double, not actual model weights')
        model = Mock(task='detect', names=dict(enumerate(str(i) for i in range(80))))
        model.model.yaml = {'scale': 's', 'yaml_file': 'yolo11s.yaml'}
        fake = types.ModuleType('ultralytics')
        fake.YOLO = Mock(return_value=model)
        args = runner.parser().parse_args(['--data', str(self.target/'data.yaml'), '--weights', str(weights),
                                          '--variant', 's', '--name', 'unit-run', '--device', 'cpu',
                                          '--seed', '7', '--patience', '3', '--epochs', '5'])
        with patch.dict('sys.modules', {'ultralytics': fake}), patch.object(runner, 'ROOT', self.root), \
                patch.object(runner, 'environment', return_value={'test_double': True}):
            train(args)
        kwargs = model.train.call_args.kwargs
        self.assertEqual(7, kwargs['seed'])
        self.assertEqual(3, kwargs['patience'])
        self.assertFalse(kwargs['cls_remap'])
        self.assertTrue(kwargs['deterministic'])
        self.assertTrue(kwargs['val'])
        self.assertFalse(kwargs['resume'])
        saved = json.loads((self.root/'training-runs/roboflow-v3/unit-run/experiment.json').read_text())
        self.assertEqual('completed', saved['state'])
        self.assertEqual(sha256(weights), saved['initial_checkpoint_sha256'])
        self.assertEqual(sha256(self.target/'review.json'), saved['review_sha256'])

    def test_evaluation_saves_per_class_ap_and_confusion_matrix_without_aliasing(self):
        from unittest.mock import Mock
        import types
        report = self.do_import()
        self.approved_review(report)
        weights = self.root/'fixture.pt'
        weights.write_bytes(b'test double')
        names = mapping()['model_names']
        box = SimpleNamespace(ap_class_index=np.arange(11), mean_results=lambda: [.8,.7,.6,.5],
                              class_result=lambda i: [.8,.7,.6,.5])
        model = Mock(task='detect', names=dict(enumerate(names)))
        model.val.return_value = SimpleNamespace(box=box, confusion_matrix=SimpleNamespace(matrix=np.eye(12)))
        fake = types.ModuleType('ultralytics')
        fake.YOLO = Mock(return_value=model)
        args = evaluator.parser().parse_args(['--data', str(self.target/'data.yaml'), '--weights', str(weights),
                                             '--name', 'unit-eval', '--device', 'cpu'])
        with patch.dict('sys.modules', {'ultralytics': fake}), patch.object(evaluator, 'ROOT', self.root), \
                patch.object(evaluator, 'environment', return_value={'test_double': True}):
            evaluator.evaluate(args)
        saved = json.loads((self.root/'evaluation-runs/roboflow-v3/unit-eval/evaluation.json').read_text())
        self.assertEqual('completed', saved['state'])
        self.assertEqual('test', model.val.call_args.kwargs['split'])
        self.assertEqual(.001, model.val.call_args.kwargs['conf'])
        self.assertEqual(12, len(saved['metrics']['confusion_matrix']['values']))
        self.assertEqual('NOT_PRESENT_IN_SOURCE_TAXONOMY', saved['metrics']['focus_classes']['BROKEN_GLASS']['status'])
        model.names = {0: 'SCRATCH', 1: 'DENT', 2: 'CRACK', 3: 'BROKEN_PART', 4: 'BROKEN_GLASS'}
        args.name = 'reject-cardd'
        with patch.dict('sys.modules', {'ultralytics': fake}), patch.object(evaluator, 'ROOT', self.root):
            with self.assertRaisesRegex(ValueError, 'CarDD mAP'):
                evaluator.evaluate(args)
        self.assertFalse((self.root/'evaluation-runs/roboflow-v3/reject-cardd').exists())


class MetricsTest(unittest.TestCase):
    def test_class_ap_uses_supported_ids_and_missing_glass_is_not_fabricated(self):
        names = mapping()['model_names']
        box = SimpleNamespace(ap_class_index=np.array([0, 6, 7, 8]),
                              mean_results=lambda: [.8, .7, .6, .5],
                              class_result=lambda index: [.81, .71, .61, .51])
        metrics = SimpleNamespace(box=box, confusion_matrix=SimpleNamespace(matrix=np.zeros((12, 12))))
        report = metric_report(metrics, names, {n: 1 if i in (0,6,7,8) else 0 for i,n in enumerate(names)})
        self.assertEqual(.51, report['per_class']['BROKEN_LAMP']['map50_95'])
        self.assertIsNone(report['per_class']['DENT_HAIL']['map50_95'])
        self.assertEqual('NOT_PRESENT_IN_SOURCE_TAXONOMY', report['focus_classes']['BROKEN_GLASS']['status'])
        self.assertIn('CRACKED_GLASS', report['focus_classes'])
