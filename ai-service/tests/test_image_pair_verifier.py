"""Image-pair gate regression tests with deterministic synthetic textures."""
import unittest

import numpy as np
from PIL import Image

from app.image_pair_verifier import ImagePairVerifier


class ImagePairVerifierTests(unittest.TestCase):
    @staticmethod
    def textured_image(seed: int) -> Image.Image:
        generator = np.random.default_rng(seed)
        # Fixed high-detail vehicle-like local surface surrogate; tests geometry,
        # not the ability to identify a real vehicle.
        image = generator.integers(35, 220, (720, 960, 3), dtype=np.uint8)
        return Image.fromarray(image, "RGB")

    def test_matching_crop_of_same_surface_is_accepted(self) -> None:
        context = self.textured_image(2026)
        close = context.crop((280, 160, 620, 440)).resize((680, 560))
        result = ImagePairVerifier().verify(close, context)
        self.assertTrue(result.suitable, result.message)
        self.assertEqual("PAIR_REGION_MATCHED", result.code)

    def test_unrelated_vehicle_surfaces_are_rejected(self) -> None:
        context = self.textured_image(2026)
        other_vehicle = self.textured_image(2027)
        close = other_vehicle.crop((280, 160, 620, 440)).resize((680, 560))
        result = ImagePairVerifier().verify(close, context)
        self.assertFalse(result.suitable)
        self.assertEqual("INSUFFICIENT_VISUAL_OVERLAP", result.code)

    def test_matching_surface_but_unrelated_damage_location_is_rejected(self) -> None:
        context = self.textured_image(2026)
        close = context.crop((280, 160, 620, 440)).resize((680, 560))
        result = ImagePairVerifier().verify(
            close, context, damage_boxes=[(720, 610, 770, 670)],
        )
        self.assertFalse(result.suitable)
        self.assertEqual("DAMAGE_REGION_UNVERIFIED", result.code)

    def test_flat_surfaces_fail_closed_without_visual_evidence(self) -> None:
        close = Image.new("RGB", (400, 400), (90, 90, 90))
        context = Image.new("RGB", (800, 600), (90, 90, 90))
        result = ImagePairVerifier().verify(close, context)
        self.assertFalse(result.suitable)
        self.assertEqual("INSUFFICIENT_VISUAL_OVERLAP", result.code)


if __name__ == "__main__":
    unittest.main()
