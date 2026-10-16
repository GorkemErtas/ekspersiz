"""Fast cheap image gates: no torch, YOLO or neural model required."""
from io import BytesIO
import unittest
from unittest.mock import Mock, patch

import numpy as np
from PIL import Image, ImageDraw

from app.image_preflight import (
    reject_obviously_unrelated_pair,
    validate_close_image_without_model,
)


def image_bytes(image: Image.Image, fmt: str = "JPEG") -> bytes:
    data = BytesIO()
    image.save(data, format=fmt)
    return data.getvalue()


def surface(seed: int) -> Image.Image:
    generator = np.random.default_rng(seed)
    picture = Image.new("RGB", (960, 720), (130, 155, 175))
    draw = ImageDraw.Draw(picture)
    for i in range(650):
        x = int(generator.integers(20, 940))
        y = int(generator.integers(20, 700))
        r = int(generator.integers(5, 18))
        col = tuple(int(v) for v in generator.integers(20, 235, 3))
        draw.ellipse((x-r, y-r, x+r, y+r), fill=col, outline=(10, 10, 10), width=2)
        if i % 4 == 0:
            draw.line((x-r, y+r, x+r, y-r), fill="white", width=2)
    return picture


class ImagePreflightTests(unittest.TestCase):
    def test_identical_files_are_rejected_without_models(self):
        picture = image_bytes(surface(14))
        outcome = reject_obviously_unrelated_pair(picture, picture)
        self.assertIsNotNone(outcome)
        self.assertFalse(outcome.suitable)
        self.assertEqual("DUPLICATE_IMAGE", outcome.code)

    def test_reencoded_same_photo_is_rejected(self):
        picture = surface(15)
        outcome = reject_obviously_unrelated_pair(
            image_bytes(picture, "JPEG"), image_bytes(picture, "PNG")
        )
        self.assertIsNotNone(outcome)
        self.assertEqual("DUPLICATE_IMAGE", outcome.code)

    def test_unrelated_surfaces_are_never_approved_by_cheap_gate(self):
        # A few accidental matches can make the result inconclusive; only
        # the full verifier may approve a pair.
        close = image_bytes(surface(14))
        context = image_bytes(surface(28))
        outcome = reject_obviously_unrelated_pair(close, context)
        self.assertTrue(outcome is None or not outcome.suitable)

    def test_strong_high_texture_nonmatch_is_rejected_without_yolo(self):
        close = image_bytes(surface(14))
        context = image_bytes(surface(28))
        detector = Mock()
        detector.detectAndCompute.return_value = (
            list(range(200)), np.ones((200, 128), dtype=np.float32)
        )
        matcher = Mock()
        matcher.knnMatch.return_value = []
        with patch(
            "app.image_preflight.cv2.SIFT_create", return_value=detector
        ), patch(
            "app.image_preflight.cv2.BFMatcher", return_value=matcher
        ):
            result = reject_obviously_unrelated_pair(close, context)
        self.assertIsNotNone(result)
        self.assertEqual("NO_SHARED_VISUAL_FEATURES", result.code)

    def test_related_close_and_wide_surfaces_are_passed_to_final_verifier(self):
        wide = surface(14)
        close = wide.crop((260, 170, 620, 470)).resize((720, 600))
        self.assertIsNone(
            reject_obviously_unrelated_pair(
                image_bytes(close), image_bytes(wide)
            )
        )

    def test_uncertain_low_texture_pair_is_delegated_not_falsely_rejected(self):
        close = image_bytes(Image.new("RGB", (320, 320), (150, 150, 150)))
        wide = image_bytes(Image.new("RGB", (700, 500), (145, 145, 145)))
        self.assertIsNone(reject_obviously_unrelated_pair(close, wide))

    def test_close_quality_matches_existing_brightness_rule(self):
        dark = image_bytes(Image.new("RGB", (128, 128), (5, 5, 5)))
        self.assertEqual(
            "TOO_DARK", validate_close_image_without_model(dark).code
        )

    def test_close_quality_matches_existing_blur_rule(self):
        light_blank = image_bytes(Image.new("RGB", (128, 128), (180, 180, 180)))
        self.assertEqual(
            "TOO_BLURRY",
            validate_close_image_without_model(light_blank).code,
        )


if __name__ == "__main__":
    unittest.main()
