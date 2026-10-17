"""Preserve the previous float64 quality decisions while reusing its scratch buffer."""
import unittest
from unittest.mock import patch

import cv2
import numpy as np
from PIL import Image

from app.damage_analyzer import DamageAnalyzer


class PhotoQualityMemoryTest(unittest.TestCase):
    def test_scores_are_exactly_equal_to_previous_numpy_variance(self):
        rng = np.random.default_rng(2026)
        for shape in ((1, 1), (2, 3), (31, 47), (480, 640), (1024, 1536)):
            pixels = rng.integers(0, 256, shape, dtype=np.uint8)
            for image in (pixels, cv2.GaussianBlur(pixels, (5, 5), 2)):
                with self.subTest(shape=shape, blurred=image is not pixels):
                    original = image.copy()
                    expected = float(cv2.Laplacian(image, cv2.CV_64F).var())
                    self.assertEqual(expected, DamageAnalyzer._blur_score(image))
                    np.testing.assert_array_equal(original, image)

    def test_float64_is_preserved_with_a_nonzero_laplacian_mean(self):
        # Border pixels make assuming a zero mean incorrect.
        pixels = np.zeros((13, 17), dtype=np.uint8)
        pixels[0, :] = 255
        laplacian = cv2.Laplacian(pixels, cv2.CV_64F)
        self.assertNotEqual(0, laplacian.mean())
        self.assertEqual(float(laplacian.var()), DamageAnalyzer._blur_score(pixels))

    def test_quality_decisions_at_and_next_to_existing_blur_threshold(self):
        analyzer = DamageAnalyzer.__new__(DamageAnalyzer)
        analyzer.minimum_brightness = 35.0
        analyzer.minimum_blur_score = 20.0
        for variance in (np.nextafter(20.0, 0), 20.0, np.nextafter(20.0, np.inf)):
            with self.subTest(variance=variance), patch.object(analyzer, "_blur_score", return_value=variance):
                issue = analyzer._photometric_quality_issue(Image.new("RGB", (16, 16), "white"))
                self.assertEqual(variance < 20.0, issue is not None)
                if issue is not None:
                    self.assertEqual("TOO_BLURRY", issue.code)

    def test_brightness_boundary_and_dark_early_exit_are_preserved(self):
        analyzer = DamageAnalyzer.__new__(DamageAnalyzer)
        analyzer.minimum_brightness = 35.0
        analyzer.minimum_blur_score = 20.0
        with patch.object(analyzer, "_blur_score", return_value=20.0) as blur:
            self.assertEqual("TOO_DARK", analyzer._photometric_quality_issue(Image.new("RGB", (16, 16), (34, 34, 34))).code)
            blur.assert_not_called()
            self.assertIsNone(analyzer._photometric_quality_issue(Image.new("RGB", (16, 16), (35, 35, 35))))
            blur.assert_called_once()


if __name__ == "__main__":
    unittest.main()
