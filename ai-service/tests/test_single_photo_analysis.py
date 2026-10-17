from io import BytesIO
import unittest
from unittest.mock import Mock, patch

import numpy as np
from PIL import Image

from app.damage_analyzer import DamageAnalyzer
from app.schemas import BoundingBox, DetectedObject


def detection(label, confidence=0.9, box=(20, 20, 160, 150)):
    return DetectedObject(
        label=label, confidence=confidence,
        boundingBox=BoundingBox(x1=box[0], y1=box[1], x2=box[2], y2=box[3]),
    )


class SinglePhotoAnalysisTest(unittest.TestCase):
    def setUp(self):
        self.analyzer = DamageAnalyzer.__new__(DamageAnalyzer)
        # Production settings, with inference mocked rather than changing thresholds.
        self.analyzer.vehicle_confidence_threshold = .40
        self.analyzer.damage_confidence_threshold = .25
        self.analyzer.damage_iou_threshold = .45
        self.analyzer.vehicle_part_confidence_threshold = .25
        self.analyzer.minimum_part_overlap_ratio = .25
        self.analyzer.affected_part_damage_confidence_threshold = .50
        self.analyzer.damage_recommendation_confidence_threshold = .30
        self.analyzer.minimum_brightness = 35.0
        self.analyzer.minimum_blur_score = 20.0
        self.analyzer.damage_class_mapping = {0: "SCRATCH"}
        self.analyzer.vehicle_model = Mock()
        self.analyzer.vehicle_part_model = Mock()
        self.analyzer.damage_model = Mock()
        pixels = ((np.indices((180, 240)).sum(axis=0) % 2) * 100 + 80).astype(np.uint8)
        output = BytesIO()
        Image.fromarray(pixels).convert("RGB").save(output, "PNG")
        self.image_bytes = output.getvalue()

    def test_partial_vehicle_uses_full_resolution_and_region_on_same_photo(self):
        part = detection("back-bumper")
        damage = detection("SCRATCH", box=(30, 40, 80, 90))
        with patch.object(self.analyzer, "_extract_detections", side_effect=[[], [part], [damage]]):
            result = self.analyzer.analyze(self.image_bytes, "partial.png", "FRONT")

        self.assertEqual(["FRONT_BUMPER"], [part.value for part in result.affectedParts])
        self.assertEqual((240, 180), self.analyzer.damage_model.predict.call_args.kwargs["source"].size)
        self.assertEqual((240, 180), self.analyzer.vehicle_part_model.predict.call_args.kwargs["source"].size)
        self.assertEqual(30, result.detections[0].boundingBox.x1)
        self.assertEqual(.25, self.analyzer.damage_model.predict.call_args.kwargs["conf"])
        self.analyzer.vehicle_part_model.predict.assert_called_once()
        self.analyzer.damage_model.predict.assert_called_once()

    def test_partial_vehicle_without_damage_preserves_canonical_clean_result(self):
        with patch.object(self.analyzer, "_extract_detections", side_effect=[[], [detection("hood")], []]):
            result = self.analyzer.analyze(self.image_bytes, "clean-part.png", "FRONT")
        self.assertEqual("NONE", result.damageSeverity.value)
        self.assertEqual(["NO_VISIBLE_DAMAGE"], [value.value for value in result.damageTypes])
        self.assertEqual("NO_ACTION", result.repairRecommendations[0].recommendedAction.value)

    def test_clear_non_vehicle_image_requires_recognizable_automotive_evidence(self):
        with patch.object(self.analyzer, "_extract_detections", side_effect=[[], []]):
            with self.assertRaisesRegex(ValueError, "çevresindeki parçayı"):
                self.analyzer.analyze(self.image_bytes, "wall.png", "REAR")
        self.analyzer.damage_model.predict.assert_not_called()

    def test_unknown_part_label_is_not_automotive_evidence(self):
        with patch.object(self.analyzer, "_extract_detections", side_effect=[[], [detection("unmapped-object")]]):
            with self.assertRaises(ValueError):
                self.analyzer.analyze(self.image_bytes, "unknown.png")

    def test_region_never_invents_an_unmatched_part(self):
        damage = detection("DENT", box=(180, 10, 210, 30))
        with patch.object(self.analyzer, "_extract_detections", side_effect=[[], [detection("front-door")], [damage]]):
            result = self.analyzer.analyze(self.image_bytes, "unmatched.png", "REAR")
        self.assertEqual("UNKNOWN", result.detections[0].affectedPart)
        self.assertEqual([], result.affectedParts)

    def test_unpaired_part_is_not_changed_by_region(self):
        damage = detection("BROKEN_PART", box=(40, 40, 70, 70))
        with patch.object(self.analyzer, "_extract_detections", side_effect=[[], [detection("headlight")], [damage]]):
            result = self.analyzer.analyze(self.image_bytes, "headlight.png", "REAR")
        self.assertEqual(["HEADLIGHT"], [part.value for part in result.affectedParts])

    def test_full_vehicle_crop_and_original_coordinate_mapping_are_preserved(self):
        vehicle = detection("car", box=(50, 40, 200, 160))
        damage = detection("SCRATCH", box=(20, 20, 60, 60))
        part = detection("front-wheel", box=(10, 10, 90, 90))
        with patch.object(self.analyzer, "_extract_detections", side_effect=[[vehicle], [damage], [part]]):
            result = self.analyzer.analyze(self.image_bytes, "car.png", "REAR")
        # Existing 5% padding and crop coordinates are unchanged.
        self.assertEqual((164, 132), self.analyzer.damage_model.predict.call_args.kwargs["source"].size)
        self.assertEqual(63, result.detections[0].boundingBox.x1)
        self.assertEqual(54, result.detections[0].boundingBox.y1)
        self.assertEqual("REAR_WHEEL", result.detections[0].affectedPart.value)

    def test_damage_classes_and_repair_rules_survive_partial_fallback(self):
        for label, action in [("SCRATCH", "PAINT_TOUCH_UP"), ("DENT", "DENT_REPAIR"),
                              ("CRACK", "PART_REPAIR"), ("BROKEN_PART", "PART_REPLACEMENT"),
                              ("BROKEN_GLASS", "GLASS_REPLACEMENT")]:
            with self.subTest(label=label):
                damage = detection(label, .95, (40, 40, 70, 70))
                with patch.object(self.analyzer, "_extract_detections", side_effect=[[], [detection("front-door")], [damage]]):
                    result = self.analyzer.analyze(self.image_bytes, "damage.png", "REAR")
                self.assertEqual(label, result.damageTypes[0].value)
                self.assertEqual(action, result.repairRecommendations[0].recommendedAction.value)
                self.assertEqual("REAR_DOOR", result.detections[0].affectedPart.value)

    def test_low_confidence_scratch_is_retained_without_a_new_threshold(self):
        with patch.object(self.analyzer, "_extract_detections", side_effect=[[], [detection("front-bumper")], [detection("SCRATCH", .28, (40, 40, 70, 70))]]):
            result = self.analyzer.analyze(self.image_bytes, "light-scratch.png", "FRONT")
        self.assertEqual("MINOR", result.damageSeverity.value)
        self.assertEqual(.28, result.confidenceScore)
        self.assertEqual("SCRATCH", result.damageTypes[0].value)

    def test_dark_and_blurry_single_images_are_rejected_before_inference(self):
        for color, message in [(5, "karanlık"), (180, "net değil")]:
            with self.subTest(color=color):
                output = BytesIO()
                Image.new("RGB", (200, 200), (color, color, color)).save(output, "PNG")
                with self.assertRaisesRegex(ValueError, message):
                    self.analyzer.analyze(output.getvalue(), "bad.png", "FRONT")
        self.analyzer.vehicle_model.predict.assert_not_called()

    def test_invalid_region_is_rejected_before_inference(self):
        with self.assertRaisesRegex(ValueError, "FRONT or REAR"):
            self.analyzer.analyze(self.image_bytes, "invalid.png", "SIDE")
        self.analyzer.vehicle_model.predict.assert_not_called()


if __name__ == "__main__":
    unittest.main()
