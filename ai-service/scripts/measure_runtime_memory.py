"""Cold-load smoke for the committed YOLO checkpoints. Uses only synthetic data."""
import asyncio
import io
import json
import resource
import sys
import time
from types import SimpleNamespace
from unittest.mock import AsyncMock

import main

assert "torch" not in sys.modules, "PyTorch loaded on assistant/health startup"
assert "ultralytics" not in sys.modules, "YOLO loaded on assistant/health startup"
assert main.health_check()["status"] == "UP"

import cv2
assert hasattr(cv2, "imshow"), "OpenCV binary namespace is incomplete"
import numpy as np
from PIL import Image

# Confirm RGB decoding produces identical pixels without the redundant copy.
from app.damage_analyzer import DamageAnalyzer
with Image.open(io.BytesIO(image_bytes)) as uploaded_image:
    expected_rgb = uploaded_image.convert("RGB").copy()
decoded_rgb = DamageAnalyzer._load_image(image_bytes)
assert np.array_equal(np.asarray(expected_rgb), np.asarray(decoded_rgb))
expected_rgb.close()
decoded_rgb.close()

noise = np.random.default_rng(2026).integers(0, 256, (480, 640, 3), dtype=np.uint8)
image = Image.fromarray(noise, "RGB")
with io.BytesIO() as stream:
    image.save(stream, "JPEG", quality=85)
    image_bytes = stream.getvalue()

upload = SimpleNamespace(filename="test.jpg", content_type="image/jpeg",
    read=AsyncMock(return_value=image_bytes), close=AsyncMock())
started = time.perf_counter()
response = asyncio.run(main.validate_image_quality(upload, purpose="context"))
cold_start_seconds = time.perf_counter() - started
assert response.code in {"SUITABLE", "NO_VEHICLE", "VEHICLE_TOO_SMALL"}, response
upload.close.assert_awaited_once()

analyzer = main.get_damage_analyzer()
assert analyzer.damage_class_mapping, "Damage checkpoint mapping missing"

import torch
timings = {}
detections = {}
for name, model in (("vehicle", analyzer.vehicle_model),
                    ("damage", analyzer.damage_model),
                    ("vehicle_part", analyzer.vehicle_part_model)):
    started = time.perf_counter()
    result = model.predict(source=image, conf=0.25, imgsz=640, device="cpu", verbose=False)
    assert result and result[0].boxes is not None, name
    timings[name] = round(time.perf_counter() - started, 3)
    detections[name] = [
        {"class": int(box.cls[0]), "confidence": round(float(box.conf[0]), 4)}
        for box in result[0].boxes
    ]

# Probe temporary allocations from phone-sized images with real image validation.
# This does not use user photos and never changes trained model weights.
import gc
import ctypes
import os


def current_rss_mib():
    with open("/proc/self/statm", encoding="ascii") as stream:
        resident_pages = int(stream.readline().split()[1])
    return round(resident_pages * os.sysconf("SC_PAGE_SIZE") / (1024 * 1024), 1)


rss_warm_mib = current_rss_mib()
large_pixels = np.random.default_rng(2027).integers(0, 256, (2304, 3072, 3), dtype=np.uint8)
large_image = Image.fromarray(large_pixels, "RGB")
with io.BytesIO() as stream:
    large_image.save(stream, "JPEG", quality=75)
    large_bytes = stream.getvalue()
large_image.close()
del large_image, large_pixels
assert len(large_bytes) < main.MAX_IMAGE_SIZE_BYTES
large_quality_codes = []
for purpose in ("damage", "context", "damage", "context"):
    upload = SimpleNamespace(filename="large.jpg", content_type="image/jpeg",
        read=AsyncMock(return_value=large_bytes), close=AsyncMock())
    result = asyncio.run(main.validate_image_quality(upload, purpose=purpose))
    large_quality_codes.append(result.code)
    upload.close.assert_awaited_once()
del upload, result, large_bytes
rss_after_large_mib = current_rss_mib()
gc.collect()
rss_after_gc_mib = current_rss_mib()
libc = ctypes.CDLL("libc.so.6")
trim_result = libc.malloc_trim(0)
rss_after_trim_mib = current_rss_mib()

print("MEMORY_SMOKE_RESULT=" + json.dumps({
    "result": "PASS", "environment": "GitHub Actions, not Railway",
    "first_image_request_seconds": round(cold_start_seconds, 3),
    "peak_rss_mib": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024, 1),
    "model_inference_seconds": timings, "torch": torch.__version__,
    "torch_cpu_threads": torch.get_num_threads(),
    "trim_feature_enabled": __import__("os").getenv("AI_TRIM_HEAP_AFTER_INFERENCE") == "true",
    "detections": detections, "image_quality_code": response.code,
    "large_quality_codes": large_quality_codes,
    "rss_warm_mib": rss_warm_mib,
    "rss_after_large_mib": rss_after_large_mib,
    "rss_after_gc_mib": rss_after_gc_mib,
    "rss_after_trim_mib": rss_after_trim_mib,
    "malloc_trim_returned": int(trim_result),
}, sort_keys=True))
