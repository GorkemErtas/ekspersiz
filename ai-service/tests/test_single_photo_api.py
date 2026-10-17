"""Exercise real ASGI multipart routing without adding an HTTP client dependency."""
import json
from io import BytesIO
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException

import main


CLEAN_RESULT = {
    "damageSeverity": "NONE", "affectedParts": [],
    "damageTypes": ["NO_VISIBLE_DAMAGE"],
    "repairRecommendations": [{"damageType": "NO_VISIBLE_DAMAGE", "recommendedAction": "NO_ACTION", "partReplacementRequired": False, "affectedParts": []}],
    "confidenceScore": 0, "analysisMessage": "Görünür hasar yok.", "detections": [],
}


async def post_multipart(fields=None, files=None):
    boundary = "single-photo-test-boundary"
    chunks = []
    for name, value in (fields or {}).items():
        chunks.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    for name, (filename, content, content_type) in (files or {}).items():
        chunks.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{filename}"\r\nContent-Type: {content_type}\r\n\r\n'.encode() + content + b"\r\n")
    chunks.append(f"--{boundary}--\r\n".encode())
    body = b"".join(chunks)
    messages = []
    delivered = False

    async def receive():
        nonlocal delivered
        if delivered:
            return {"type": "http.disconnect"}
        delivered = True
        return {"type": "http.request", "body": body, "more_body": False}

    async def send(message):
        messages.append(message)

    await main.app({
        "type": "http", "asgi": {"version": "3.0", "spec_version": "2.3"},
        "method": "POST", "path": "/api/v1/analyze", "raw_path": b"/api/v1/analyze",
        "root_path": "", "query_string": b"", "scheme": "http", "http_version": "1.1",
        "headers": [(b"content-type", f"multipart/form-data; boundary={boundary}".encode()), (b"content-length", str(len(body)).encode())],
        "client": ("127.0.0.1", 1234), "server": ("test", 80),
    }, receive, send)
    status = next(message["status"] for message in messages if message["type"] == "http.response.start")
    response_body = b"".join(message.get("body", b"") for message in messages if message["type"] == "http.response.body")
    return status, json.loads(response_body)


class SinglePhotoApiTest(unittest.IsolatedAsyncioTestCase):
    async def test_single_multipart_forwards_normalized_region_without_context(self):
        for region in (" front ", "rear"):
            with self.subTest(region=region), patch.object(main, "run_damage_operation", return_value=CLEAN_RESULT) as operation:
                status, body = await post_multipart(
                    fields={"vehicle_region": region},
                    files={"image": ("damage.jpg", b"one-image", "image/jpeg")},
                )
                self.assertEqual(200, status)
                self.assertEqual(["NO_VISIBLE_DAMAGE"], body["damageTypes"])
                operation.assert_called_once_with("analyze", file_content=b"one-image", filename="damage.jpg", vehicle_region=region.strip().upper())

    async def test_region_remains_optional_for_old_single_photo_callers(self):
        with patch.object(main, "run_damage_operation", return_value=CLEAN_RESULT) as operation:
            status, _ = await post_multipart(files={"image": ("old.jpg", b"old-client", "image/jpeg")})
            self.assertEqual(200, status)
            self.assertIsNone(operation.call_args.kwargs["vehicle_region"])

    async def test_explicit_legacy_pair_still_uses_both_images(self):
        with patch.object(main, "run_damage_operation", return_value=CLEAN_RESULT) as operation:
            status, _ = await post_multipart(fields={"vehicle_region": "REAR"}, files={
                "image": ("damage.jpg", b"damage", "image/jpeg"),
                "context_image": ("context.png", b"context", "image/png"),
            })
            self.assertEqual(200, status)
            operation.assert_called_once_with("analyze_pair", damage_file_content=b"damage", context_file_content=b"context", filename="damage.jpg", vehicle_region="REAR")

    async def test_bad_region_fails_for_single_and_pair_before_inference(self):
        for pair in (False, True):
            files = {"image": ("damage.jpg", b"damage", "image/jpeg")}
            if pair:
                files["context_image"] = ("context.jpg", b"context", "image/jpeg")
            with self.subTest(pair=pair), patch.object(main, "run_damage_operation") as operation:
                status, _ = await post_multipart(fields={"vehicle_region": "SIDE"}, files=files)
                self.assertEqual(400, status)
                operation.assert_not_called()

    async def test_file_validation_precedes_inference(self):
        for content, content_type, expected in [(b"image", "text/plain", 415), (b"", "image/jpeg", 400), (b"x" * (main.MAX_IMAGE_SIZE_BYTES + 1), "image/jpeg", 413)]:
            with self.subTest(expected=expected), patch.object(main, "run_damage_operation") as operation:
                status, _ = await post_multipart(files={"image": ("damage.jpg", content, content_type)})
                self.assertEqual(expected, status)
                operation.assert_not_called()

    async def test_invalid_visual_content_returns_retake_guidance(self):
        with patch.object(main, "run_damage_operation", side_effect=ValueError("Hasarı ve çevresindeki parçayı net gösterin.")):
            status, body = await post_multipart(files={"image": ("bad.jpg", b"image", "image/jpeg")})
            self.assertEqual(400, status)
            self.assertIn("çevresindeki parçayı", body["detail"])

    async def test_both_uploads_close_on_invalid_legacy_request(self):
        image = SimpleNamespace(filename="image.jpg", content_type="image/jpeg", read=AsyncMock(return_value=b"image"), close=AsyncMock())
        context = SimpleNamespace(close=AsyncMock())
        with self.assertRaises(HTTPException):
            await main.analyze_damage(image, context, "SIDE")
        image.close.assert_awaited_once()
        context.close.assert_awaited_once()

    async def test_corrupt_image_is_rejected_by_the_decoder(self):
        from app.damage_analyzer import DamageAnalyzer
        with self.assertRaises(ValueError):
            DamageAnalyzer._load_image(b"invalid-image-data")

    async def test_allowed_codecs_still_decode_and_corrupt_headers_do_not_install_plugins(self):
        from PIL import Image
        from app.damage_analyzer import DamageAnalyzer
        for format_name in ("JPEG", "PNG", "WEBP"):
            with self.subTest(format=format_name):
                encoded = BytesIO()
                Image.new("RGB", (30, 20), "white").save(encoded, format_name)
                decoded = DamageAnalyzer._load_image(encoded.getvalue())
                self.assertEqual((30, 20), decoded.size)
                self.assertEqual("RGB", decoded.mode)
        for content in (b"\xff\xd8broken", b"\x89PNG\r\n\x1a\nbroken", b"RIFF0000WEBPbroken"):
            with self.subTest(content=content), patch("ultralytics.utils.checks.check_requirements") as install:
                with self.assertRaises(ValueError):
                    DamageAnalyzer._load_image(content)
                install.assert_not_called()

    async def test_existing_pillow_pixel_safety_limit_is_preserved(self):
        from PIL import Image
        from app.damage_analyzer import DamageAnalyzer
        encoded = BytesIO()
        Image.new("RGB", (30, 20), "white").save(encoded, "PNG")
        with patch.object(Image, "MAX_IMAGE_PIXELS", 50):
            with self.assertRaises(ValueError):
                DamageAnalyzer._load_image(encoded.getvalue())


if __name__ == "__main__":
    unittest.main()
