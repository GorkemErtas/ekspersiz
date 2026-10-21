import struct
import unittest
import zlib
from io import BytesIO
from unittest.mock import patch

from PIL import Image
from app.damage_analyzer import DamageAnalyzer


class ImageSecurityTest(unittest.TestCase):
    def test_large_dimensions_rejected_before_decode_even_for_tiny_upload(self):
        stream = BytesIO()
        Image.new("RGB", (1, 1)).save(stream, format="PNG")
        content = bytearray(stream.getvalue())
        content[16:24] = struct.pack(">II", 10000, 10000)
        content[29:33] = struct.pack(">I", zlib.crc32(content[12:29]))
        with patch.object(Image.Image, "convert") as convert:
            with self.assertRaises(ValueError):
                DamageAnalyzer._load_image(bytes(content))
            convert.assert_not_called()

    def test_normal_jpeg_png_and_webp_still_decode_without_resize(self):
        for format in ("JPEG", "PNG", "WEBP"):
            with self.subTest(format=format):
                stream = BytesIO()
                Image.new("RGB", (64, 48)).save(stream, format=format)
                with DamageAnalyzer._load_image(stream.getvalue()) as decoded:
                    self.assertEqual((64, 48), decoded.size)
                    self.assertEqual("RGB", decoded.mode)
