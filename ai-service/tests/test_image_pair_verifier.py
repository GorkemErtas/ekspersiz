"""Image-pair gate regression tests with deterministic synthetic textures."""
import unittest

import numpy as np
from PIL import Image, ImageDraw

from app.image_pair_verifier import ImagePairVerifier


class ImagePairVerifierTests(unittest.TestCase):
    @staticmethod
    def textured_image(seed: int) -> Image.Image:
        generator = np.random.default_rng(seed)
        # Stable localized shapes survive close-up scaling; pure pixel noise
        # does not, and is not representative of real image features.
        image = Image.new("RGB", (960, 720), (135, 150, 165))
        drawer = ImageDraw.Draw(image)
        for i in range(500):
            x = int(generator.integers(20, 940))
            y = int(generator.integers(20, 700))
            radius = int(generator.integers(5, 20))
            color = tuple(int(v) for v in generator.integers(30, 235, 3))
            drawer.ellipse(
                (x - radius, y - radius, x + radius, y + radius),
                fill=color, outline="black", width=2,
            )
            if i % 4 == 0:
                drawer.line(
                    (x - radius, y + radius, x + radius, y - radius),
                    fill=(255, 255, 255), width=2,
                )
        return image

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
