"""Optional, explicitly approved *visual* severity head. Never infers repair/structural damage."""
from __future__ import annotations

import hashlib
from pathlib import Path

import numpy as np
from PIL import Image

LABELS = ("MINOR", "MODERATE", "SEVERE")
SIZE = 224
PREPROCESSING = "RGB-PIL-bilinear-ImageNet-v1"
_MEAN = np.array([.485, .456, .406], dtype=np.float32)
_STD = np.array([.229, .224, .225], dtype=np.float32)


def crop_damage(image: Image.Image, box: dict) -> Image.Image:
    """Pad a detected region with context; reject empty/out-of-bounds predictions."""
    try:
        x1, y1, x2, y2 = (float(box[key]) for key in ("x1", "y1", "x2", "y2"))
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError("Invalid severity crop") from exc
    if not np.isfinite([x1, y1, x2, y2]).all():
        raise ValueError("Nonfinite severity crop")
    if not (0 <= x1 < x2 <= image.width and 0 <= y1 < y2 <= image.height):
        raise ValueError("Severity crop outside image")
    padding = .15 * max(x2 - x1, y2 - y1)
    left = max(0, int(x1 - padding))
    upper = max(0, int(y1 - padding))
    right = min(image.width, int(np.ceil(x2 + padding)))
    lower = min(image.height, int(np.ceil(y2 + padding)))
    if right <= left or lower <= upper:
        raise ValueError("Empty severity crop")
    return image.crop((left, upper, right, lower))


def preprocess_severity(image: Image.Image) -> np.ndarray:
    pixels = np.asarray(image.convert("RGB").resize((SIZE, SIZE), Image.Resampling.BILINEAR), dtype=np.float32) / 255.
    return np.ascontiguousarray(((pixels - _MEAN) / _STD).transpose(2, 0, 1))


def classify_logits(logits: np.ndarray, threshold: float) -> str:
    """Threshold is calibrated on validation; logits are NOT confidence of physical severity."""
    arr = np.asarray(logits, dtype=np.float64)
    if arr.shape != (1, 3) or not np.isfinite(arr).all() or not (.5 <= threshold <= 1.):
        return "UNKNOWN"
    arr = arr[0] - arr[0].max()
    probabilities = np.exp(arr)
    probabilities /= probabilities.sum()
    index = int(np.argmax(probabilities))
    return LABELS[index] if probabilities[index] >= threshold else "UNKNOWN"


class VisualSeverityClassifier:
    """ONNX-only inference of appearance labels, behind an approved manifest."""
    def __init__(self, bundle: Path, config: dict):
        if config.get("labels") != list(LABELS) or config.get("preprocessing") != PREPROCESSING or config.get("input_size") != SIZE:
            raise ValueError("Unsupported severity head contract")
        if config.get("approved") is not True or config.get("validation_calibrated") is not True:
            raise ValueError("Unapproved severity checkpoint")
        if config.get("label_source") != "HITL_CC0_EXPERT_REVIEWED" or not config.get("model_version"):
            raise ValueError("Unverified severity provenance")
        threshold = config.get("threshold")
        if not isinstance(threshold, (int, float)) or not (.5 <= threshold <= 1.):
            raise ValueError("Invalid severity threshold")
        model_path = bundle / "severity.onnx"
        if hashlib.sha256(model_path.read_bytes()).hexdigest() != config.get("sha256"):
            raise ValueError("Severity checkpoint digest mismatch")
        import onnxruntime as ort
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 2
        opts.inter_op_num_threads = 1
        self.session = ort.InferenceSession(str(model_path), sess_options=opts, providers=["CPUExecutionProvider"])
        inputs, outputs = self.session.get_inputs(), self.session.get_outputs()
        if len(inputs) != 1 or inputs[0].name != "images" or inputs[0].type != "tensor(float)" or inputs[0].shape != [1, 3, SIZE, SIZE]:
            raise ValueError("Unexpected severity input signature")
        if len(outputs) != 1 or outputs[0].name != "logits" or outputs[0].shape != [1, 3]:
            raise ValueError("Unexpected severity output signature")
        self.threshold = float(threshold)

    def classify(self, image: Image.Image, detections: list) -> str:
        if not detections or len(detections) > 12:
            return "UNKNOWN"
        grades = []
        for detection in detections:
            try:
                crop = crop_damage(image, detection["boundingBox"])
                logits = self.session.run(["logits"], {"images": preprocess_severity(crop)[None]})[0]
                grade = classify_logits(logits, self.threshold)
            except (ValueError, KeyError, RuntimeError, OSError):
                return "UNKNOWN"
            if grade == "UNKNOWN":
                return "UNKNOWN"
            grades.append(grade)
        return max(grades, key=LABELS.index)
