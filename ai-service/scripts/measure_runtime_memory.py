"""Cold-load smoke for the committed YOLO checkpoints. Uses only synthetic data."""
import io
import json
import resource
import sys
import time

import main

assert "torch" not in sys.modules, "PyTorch loaded on assistant/health startup"
assert "ultralytics" not in sys.modules, "YOLO loaded on assistant/health startup"
assert main.health_check()["status"] == "UP"

import numpy as np
from PIL import Image
from fastapi.testclient import TestClient

noise = np.random.default_rng(2026).integers(0, 256, (480, 640, 3), dtype=np.uint8)
image = Image.fromarray(noise, "RGB")
with io.BytesIO() as stream:
    image.save(stream, "JPEG", quality=85)
    image_bytes = stream.getvalue()

with TestClient(main.app) as client:
    started = time.perf_counter()
    response = client.post("/api/v1/validate-image", params={"purpose": "context"},
        files={"image": ("test.jpg", image_bytes, "image/jpeg")})
    cold_start_seconds = time.perf_counter() - started
    assert response.status_code == 200, response.text[:600]
    assert response.json().get("code") in {"SUITABLE", "NO_VEHICLE", "VEHICLE_TOO_SMALL"}, response.text

analyzer = main.get_damage_analyzer()
assert analyzer.damage_class_mapping, "Damage checkpoint mapping missing"

import torch
torch.set_num_threads(2)
timings = {}
for name, model in (("vehicle", analyzer.vehicle_model),
                    ("damage", analyzer.damage_model),
                    ("vehicle_part", analyzer.vehicle_part_model)):
    started = time.perf_counter()
    result = model.predict(source=image, conf=0.25, imgsz=640, device="cpu", verbose=False)
    assert result and result[0].boxes is not None, name
    timings[name] = round(time.perf_counter() - started, 3)

print("MEMORY_SMOKE_RESULT=" + json.dumps({
    "result": "PASS", "environment": "GitHub Actions, not Railway",
    "first_image_request_seconds": round(cold_start_seconds, 3),
    "peak_rss_mib": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024, 1),
    "model_inference_seconds": timings, "torch": torch.__version__,
}, sort_keys=True))
