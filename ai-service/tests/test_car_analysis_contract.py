import unittest
from unittest.mock import patch
from pathlib import Path
import json
from tempfile import TemporaryDirectory

from app.damage_analyzer import DamageAnalyzer
from app.model_contract import DAMAGE_CLASSES, PART_CLASSES, verify_names, verify_artifact
from app.schemas import VehiclePart, DamageAnalysisResponse, ImageQualityResponse
import test_single_photo_analysis as fixtures

detection = fixtures.detection


class AutomobileContractTest(unittest.TestCase):
    setUp = fixtures.SinglePhotoAnalysisTest.setUp
    def test_unsupported_or_mixed_vehicles_never_reach_damage_inference(self):
        for label in ('motorcycle', 'truck', 'bus', 'bicycle', 'train', 'boat'):
            for objects in ([detection(label)], [detection('car'), detection(label)]):
                with self.subTest(label=label, mixed=len(objects) > 1):
                    with patch.object(self.analyzer, '_extract_detections', return_value=objects):
                        quality = self.analyzer.validate_image_quality(self.image_bytes, 'damage')
                        self.assertEqual('UNSUPPORTED_VEHICLE', quality.code)
                        with self.assertRaises(ValueError):
                            self.analyzer.analyze(self.image_bytes, 'photo.png')
        self.analyzer.damage_model.predict.assert_not_called()

    def test_shared_parts_alone_are_not_car_evidence(self):
        for objects, parts in [([], [detection('hood'), detection('front-door')]),
                               ([detection('car', .3)], [detection('headlight'), detection('front-wheel')]),
                               ([detection('car', .3)], [detection('hood', .4), detection('fender', .4)])]:
            with patch.object(self.analyzer, '_extract_detections', side_effect=[objects, parts]):
                with self.assertRaises(ValueError):
                    self.analyzer.analyze(self.image_bytes, 'ambiguous.png')
        self.analyzer.damage_model.predict.assert_not_called()

    def test_multiple_cars_and_small_car_are_rejected(self):
        for objects in ([detection('car'), detection('car')], [detection('car', box=(0, 0, 10, 10))]):
            with patch.object(self.analyzer, '_extract_detections', return_value=objects):
                with self.assertRaises(ValueError):
                    self.analyzer.analyze(self.image_bytes, 'photo.png')
        self.analyzer.damage_model.predict.assert_not_called()

    def test_partial_car_with_body_and_wheel_evidence_retains_full_image(self):
        damage = detection('SCRATCH', box=(30, 40, 80, 90))
        with patch.object(self.analyzer, '_extract_detections', side_effect=[
            [detection('car', .3, (0, 0, 240, 180))],
            [detection('front-bumper'), detection('front-wheel', box=(170, 60, 230, 170))],
            [damage],
        ]):
            result = self.analyzer.analyze(self.image_bytes, 'partial.png')
        self.assertEqual('SCRATCH', result.damageTypes[0])
        self.assertEqual('FRONT_BUMPER', result.detections[0].affectedPart)
        self.assertEqual((240, 180), self.analyzer.damage_model.predict.call_args.kwargs['source'].size)

    def test_ambiguous_weak_or_incompatible_parts_remain_unknown(self):
        cases = [
            ('SCRATCH', [detection('front-door'), detection('fender')]),
            ('SCRATCH', [detection('front-door', .4)]),
            ('SCRATCH', [detection('front-door', box=(130, 130, 160, 160))]),
            ('BROKEN_PART', [detection('front-bumper')]),
            ('BROKEN_GLASS', [detection('hood')]),
            ('DENT', [detection('headlight')]),
        ]
        for label, parts in cases:
            with self.subTest(label=label, parts=parts):
                self.assertEqual('UNKNOWN', self.analyzer._match_damage_to_vehicle_part(
                    detection(label, box=(40, 40, 70, 70)), parts))

    def test_lamp_and_glass_use_only_compatible_parts(self):
        for label, part, expected in [('BROKEN_PART', 'headlight', 'HEADLIGHT'),
                                       ('BROKEN_PART', 'tail-light', 'TAIL_LIGHT'),
                                       ('BROKEN_GLASS', 'windshield', 'WINDSHIELD')]:
            self.assertEqual(expected, self.analyzer._match_damage_to_vehicle_part(
                detection(label, box=(40, 40, 70, 70)), [detection(part)]))

    def test_part_count_never_invents_severity(self):
        for label in DAMAGE_CLASSES:
            for count in (0, 1, 2, 5):
                self.assertEqual('UNKNOWN', self.analyzer._determine_damage_severity(label, count))


class CheckpointContractTest(unittest.TestCase):
    def test_shared_wire_fixture_matches_python_output_semantics(self):
        fixture = json.loads((Path(__file__).resolve().parents[2] / 'contracts/car-analysis-v1.json').read_text(encoding='utf-8'))
        expected = DamageAnalysisResponse.model_validate(fixture['visibleDamage'])
        analyzer = DamageAnalyzer.__new__(DamageAnalyzer)
        analyzer.damage_recommendation_confidence_threshold = .30
        actual = analyzer._build_damage_response('car.png', expected.detections[0],
                                                  expected.detections, expected.affectedParts)
        self.assertEqual(expected.model_dump(exclude={'analysisMessage'}),
                         actual.model_dump(exclude={'analysisMessage'}))
        clean = analyzer._build_no_damage_response('car.png')
        self.assertEqual(DamageAnalysisResponse.model_validate(fixture['noVisibleDamage']).model_dump(exclude={'analysisMessage'}),
                         clean.model_dump(exclude={'analysisMessage'}))
        self.assertFalse(ImageQualityResponse.model_validate(fixture['uncertainImage']).suitable)

    def test_part_mapping_covers_exactly_the_audited_checkpoint(self):
        self.assertEqual(set(DamageAnalyzer.VEHICLE_PART_MAPPING), {p.lower() for p in PART_CLASSES})
        values = list(DamageAnalyzer.VEHICLE_PART_MAPPING.values())
        self.assertEqual(21, len(set(values)))
        self.assertTrue(set(values).issubset({p.value for p in VehiclePart}))

    def test_names_reject_missing_reordered_extra_and_duplicate_classes(self):
        verify_names(dict(enumerate(PART_CLASSES)), PART_CLASSES)
        for names in [PART_CLASSES[:-1], tuple(reversed(PART_CLASSES)), PART_CLASSES + ('Tire',),
                      (PART_CLASSES[0],) * len(PART_CLASSES)]:
            with self.assertRaises(RuntimeError):
                verify_names(names, PART_CLASSES)

    def test_unreviewed_artifact_is_rejected_before_loading(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'unreviewed.pt'
            path.write_bytes(b'not a checkpoint')
            with self.assertRaisesRegex(RuntimeError, 'contract mismatch'):
                verify_artifact(path, 'damage')
