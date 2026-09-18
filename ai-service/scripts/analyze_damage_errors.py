from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from experiments.config import (  # noqa: E402
    canonicalize_damage_label,
    list_images,
    parse_model_spec,
    select_device,
)


DEFAULT_IMAGES = PROJECT_ROOT / "evaluation-images"
DEFAULT_OUTPUT = PROJECT_ROOT / "error-analysis-runs"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run models on the same real-world images for manual error review."
    )
    parser.add_argument(
        "--model",
        action="append",
        required=True,
        metavar="LABEL=PATH",
        help="Repeat to compare multiple detection models on identical images.",
    )
    parser.add_argument("--images", type=Path, default=DEFAULT_IMAGES)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--conf", type=float, default=0.10)
    parser.add_argument("--low-confidence", type=float, default=0.30)
    parser.add_argument("--iou", type=float, default=0.45)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--device", default="auto")
    return parser


def analyze(args: argparse.Namespace) -> None:
    images = list_images(args.images.resolve())
    if not images:
        raise ValueError(
            f"No evaluation images found in {args.images.resolve()}. "
            "Add real images manually before running error analysis."
        )

    manifest_path = args.manifest or args.images / "review_manifest.csv"
    expectations = load_manifest(manifest_path.resolve())
    models = [parse_model_spec(spec) for spec in args.model]
    device = select_device(args.device)
    args.output.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, Any]] = []

    from ultralytics import YOLO

    for label, model_path in models:
        model_output = args.output / label / "annotated"
        model_output.mkdir(parents=True, exist_ok=True)
        model = YOLO(str(model_path))
        for image_path in images:
            result = model.predict(
                source=str(image_path),
                conf=args.conf,
                iou=args.iou,
                imgsz=args.imgsz,
                device=device,
                max_det=20,
                verbose=False,
            )[0]
            prediction = prediction_row(result, model.names)
            expected = expectations.get(image_path.name.lower(), {})
            flags = review_flags(prediction, expected, args.low_confidence)
            result.save(filename=str(model_output / image_path.name))
            rows.append(
                {
                    "model": label,
                    "image": image_path.name,
                    **prediction,
                    "expected_damage": expected.get("expected_damage", ""),
                    "expected_types": "|".join(expected.get("expected_types", [])),
                    "review_flags": "|".join(flags),
                    "notes": expected.get("notes", ""),
                }
            )

    csv_path = args.output / "prediction-review.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    (args.output / "prediction-review.json").write_text(
        json.dumps(rows, indent=2), encoding="utf-8"
    )
    print(f"Annotated predictions and review tables saved to: {args.output.resolve()}")


def prediction_row(result: Any, names: Any) -> dict[str, Any]:
    labels: list[str] = []
    confidences: list[float] = []
    boxes = getattr(result, "boxes", None)
    if boxes is not None:
        class_ids = boxes.cls.cpu().tolist()
        confidences = [round(float(value), 6) for value in boxes.conf.cpu().tolist()]
        for class_id in class_ids:
            raw_name = names[int(class_id)] if isinstance(names, dict) else names[int(class_id)]
            labels.append(canonicalize_damage_label(str(raw_name)))

    return {
        "predicted_damage": bool(labels),
        "predicted_types": "|".join(labels),
        "confidences": "|".join(str(value) for value in confidences),
        "highest_confidence": max(confidences, default=0.0),
        "instance_count": len(labels),
    }


def load_manifest(path: Path) -> dict[str, dict[str, Any]]:
    if not path.is_file():
        return {}
    result: dict[str, dict[str, Any]] = {}
    with path.open("r", newline="", encoding="utf-8-sig") as stream:
        for row in csv.DictReader(stream):
            image = (row.get("image") or "").strip().lower()
            if not image:
                continue
            raw_expected = (row.get("expected_damage") or "").strip().lower()
            expected_damage: bool | str = ""
            if raw_expected in {"true", "yes", "1"}:
                expected_damage = True
            elif raw_expected in {"false", "no", "0"}:
                expected_damage = False
            raw_types = (row.get("expected_types") or "").split("|")
            result[image] = {
                "expected_damage": expected_damage,
                "expected_types": [
                    canonicalize_damage_label(value) for value in raw_types if value.strip()
                ],
                "notes": (row.get("notes") or "").strip(),
            }
    return result


def review_flags(
    prediction: dict[str, Any],
    expected: dict[str, Any],
    low_confidence: float,
) -> list[str]:
    flags: list[str] = []
    expected_damage = expected.get("expected_damage", "")
    predicted_damage = bool(prediction["predicted_damage"])
    if expected_damage is False and predicted_damage:
        flags.append("CLEAN_FALSE_POSITIVE")
        if float(prediction["highest_confidence"]) < low_confidence:
            flags.append("LOW_CONFIDENCE_FALSE_POSITIVE")
    if expected_damage is True and not predicted_damage:
        flags.append("MISSED_DAMAGE")

    expected_types = set(expected.get("expected_types", []))
    predicted_types = set(filter(None, str(prediction["predicted_types"]).split("|")))
    if expected_types and predicted_damage and expected_types.isdisjoint(predicted_types):
        flags.append("INCORRECT_DAMAGE_TYPE")
    if predicted_damage:
        flags.append("MANUAL_LOCALIZATION_REVIEW")
    return flags


def main() -> None:
    analyze(build_parser().parse_args())


if __name__ == "__main__":
    main()
