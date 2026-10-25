"""Safety contracts for the optional, not-yet-trained severity classifier."""
import hashlib
from pathlib import Path
import tempfile
import unittest

import numpy as np
from PIL import Image

from app.vision.severity import (VisualSeverityClassifier, LABELS, PREPROCESSING,
                                 crop_damage, preprocess_severity, classify_logits)


class SeverityTest(unittest.TestCase):
    def test_crop_keeps_context_and_rejects_invalid_boxes(self):
        image = Image.new("RGB", (200, 100), (20, 30, 40))
        crop = crop_damage(image, {"x1": 40, "y1": 20, "x2": 70, "y2": 40})
        self.assertGreater(crop.width, 30)
        self.assertGreater(crop.height, 20)
        for invalid in ({"x1": -1, "y1": 0, "x2": 40, "y2": 10},
                        {"x1": 10, "y1": 5, "x2": 10, "y2": 20},
                        {"x1": float("nan"), "y1": 5, "x2": 20, "y2": 40}):
            with self.assertRaises(ValueError):
                crop_damage(image, invalid)

    def test_preprocess_is_rgb_chw_and_finite(self):
        image = Image.new("RGB", (25, 40), (255, 0, 0))
        pixels = preprocess_severity(image)
        self.assertEqual((3, 224, 224), pixels.shape)
        self.assertEqual(np.float32, pixels.dtype)
        self.assertTrue(np.isfinite(pixels).all())
        self.assertAlmostEqual((1. - .485) / .229, float(pixels[0, 100, 100]), places=5)
        self.assertAlmostEqual((0. - .456) / .224, float(pixels[1, 100, 100]), places=5)

    def test_only_valid_calibrated_high_score_is_emitted(self):
        self.assertEqual("SEVERE", classify_logits(np.array([[0, 0, 10]], np.float32), .8))
        self.assertEqual("UNKNOWN", classify_logits(np.array([[1, 1, 1]], np.float32), .8))
        self.assertEqual("UNKNOWN", classify_logits(np.array([[0, np.nan, 1]], np.float32), .8))
        self.assertEqual("UNKNOWN", classify_logits(np.array([[0, 1]], np.float32), .8))

    def test_unapproved_and_unverified_weights_cannot_initialize(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "severity.onnx").write_bytes(b"untrusted")
            config = {"labels": list(LABELS), "preprocessing": PREPROCESSING,
                      "input_size": 224, "approved": False, "validation_calibrated": True,
                      "label_source": "HITL_CC0_EXPERT_REVIEWED",
                      "model_version": "test", "threshold": .8,
                      "sha256": hashlib.sha256(b"untrusted").hexdigest()}
            with self.assertRaises(ValueError):
                VisualSeverityClassifier(path, config)
            config["approved"] = True
            config["sha256"] = "0" * 64
            with self.assertRaises(ValueError):
                VisualSeverityClassifier(path, config)

    def test_multi_damage_requires_all_classifications_confident(self):
        class FakeSession:
            def __init__(self, outputs):
                self.outputs = list(outputs)
            def run(self, outputs, inputs):
                return [self.outputs.pop(0)]
        detector = object.__new__(VisualSeverityClassifier)
        detector.threshold = .8
        detector.session = FakeSession([np.array([[10, 0, 0]]), np.array([[0, 0, 10]])])
        image = Image.new("RGB", (200, 100), (100, 100, 100))
        instances = [{"boundingBox": {"x1": 10, "y1": 10, "x2": 30, "y2": 30}},
                     {"boundingBox": {"x1": 50, "y1": 10, "x2": 80, "y2": 40}}]
        self.assertEqual("SEVERE", detector.classify(image, instances))
        detector.session = FakeSession([np.array([[10, 0, 0]]), np.array([[0, 0, 0]])])
        self.assertEqual("UNKNOWN", detector.classify(image, instances))
        self.assertEqual("UNKNOWN", detector.classify(image, []))


if __name__ == "__main__":
    unittest.main()
