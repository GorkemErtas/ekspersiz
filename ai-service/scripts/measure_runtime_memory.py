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

print("MEMORY_SMOKE_RESULT=" + json.dumps({
    "result": "PASS", "environment": "GitHub Actions, not Railway",
    "first_image_request_seconds": round(cold_start_seconds, 3),
    "peak_rss_mib": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024, 1),
    "model_inference_seconds": timings, "torch": torch.__version__,
    "torch_cpu_threads": torch.get_num_threads(),
    "detections": detections, "image_quality_code": response.code,
}, sort_keys=True))
