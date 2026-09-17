from __future__ import annotations

import argparse
import csv
import json
import math
import os
import shutil
import sys
from pathlib import Path
from typing import Any

import yaml


PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from experiments.config import (  # noqa: E402
    canonical_damage_classes,
    canonicalize_damage_label,
    list_images,
    parse_model_spec,
    resolve_split_path,
    select_device,
    validate_dataset_config,
)


DEFAULT_DETECTION_DATA = (
    PROJECT_ROOT / "datasets" / "vehicle_damage_detection_v2" / "data.yaml"
)
DEFAULT_OUTPUT = PROJECT_ROOT / "evaluation-runs"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Evaluate one or more YOLO damage models on the same split."
    )
    parser.add_argument(
        "--model",
        action="append",
        required=True,
        metavar="LABEL=PATH",
        help="Repeat for each model being compared.",
    )
    parser.add_argument("--task", choices=("detect", "segment"), default="detect")
    parser.add_argument("--data", type=Path, default=DEFAULT_DETECTION_DATA)
    parser.add_argument("--split", choices=("val", "test"), default="test")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--conf", type=float, default=0.001)
    parser.add_argument("--iou", type=float, default=0.60)
    parser.add_argument("--device", default="auto")
    return parser


def metric_report(metrics: Any, task: str, names: Any) -> dict[str, Any]:
    metric = getattr(metrics, "seg" if task == "segment" else "box", None)
    if metric is None:
        raise ValueError(f"Ultralytics returned no {task} metrics.")

    precision, recall, map50, map50_95 = [
        _finite_float(value) for value in metric.mean_results()
    ]
    report: dict[str, Any] = {
        "precision": precision,
        "recall": recall,
        "map50": map50,
        "map50_95": map50_95,
        "per_class": [],
    }
    normalized_names = canonical_model_names(names)
    class_positions = {
        int(class_id): position
        for position, class_id in enumerate(getattr(metric, "ap_class_index", []))
    }
    for class_id, class_name in normalized_names.items():
        position = class_positions.get(class_id)
        values = (
            [_finite_float(value) for value in metric.class_result(position)]
            if position is not None
            else [None, None, None, None]
        )
        report["per_class"].append(
            {
                "class_id": class_id,
                "class_name": class_name,
                "precision": values[0],
                "recall": values[1],
                "map50": values[2],
                "map50_95": values[3],
            }
        )
    return report


def evaluate(args: argparse.Namespace) -> None:
    data_path = args.data.resolve()
    dataset = validate_dataset_config(data_path)
    split_path = resolve_split_path(data_path, dataset, args.split)
    if not list_images(split_path):
        raise ValueError(f"The '{args.split}' split contains no images: {split_path}")

    model_specs = [parse_model_spec(spec) for spec in args.model]
    model_labels = [label for label, _ in model_specs]
    if len(set(model_labels)) != len(model_labels):
        raise ValueError("Every evaluated model must have a unique label.")
    device = select_device(args.device)
    args.output.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, Any]] = []

    from ultralytics import YOLO

    models = [(label, model_path, YOLO(str(model_path))) for label, model_path in model_specs]
    class_maps = [canonical_model_names(model.names) for _, _, model in models]
    shared_classes = shared_model_classes(class_maps)
    if not shared_classes:
        raise ValueError("The supplied models have no canonical damage classes in common.")

    for (label, model_path, model), class_map in zip(models, class_maps):
        print(f"Evaluating {label}: {model_path}")
        evaluation_data = data_path
        if len(models) > 1:
            evaluation_data = build_comparison_dataset(
                source_config_path=data_path,
                source_config=dataset,
                split=args.split,
                destination=args.output / "comparison-datasets" / label,
                model_names=model.names,
                shared_classes=shared_classes,
            )
        metrics = model.val(
            data=str(evaluation_data),
            split=args.split,
            imgsz=args.imgsz,
            batch=args.batch,
            conf=args.conf,
            iou=args.iou,
            device=device,
            plots=True,
            project=str(args.output.resolve()),
            name=label,
            exist_ok=True,
            verbose=True,
        )
        report = metric_report(metrics, args.task, model.names)
        report.update(
            {
                "model": label,
                "model_path": str(model_path),
                "task": args.task,
                "split": args.split,
                "dataset": str(data_path),
                "evaluation_scope": shared_classes,
                "model_classes": list(class_map.values()),
            }
        )
        output_file = args.output / f"{label}-metrics.json"
        output_file.write_text(json.dumps(report, indent=2), encoding="utf-8")
        for class_metrics in report["per_class"]:
            rows.append({"model": label, **class_metrics})

    comparison_file = args.output / "per-class-comparison.csv"
    with comparison_file.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=(
                "model",
                "class_id",
                "class_name",
                "precision",
                "recall",
                "map50",
                "map50_95",
            ),
        )
        writer.writeheader()
        writer.writerows(rows)
    print(f"Metrics and confusion-matrix plots saved under: {args.output.resolve()}")


def canonical_model_names(names: Any) -> dict[int, str]:
    raw_names = (
        {int(index): str(name) for index, name in names.items()}
        if isinstance(names, dict)
        else {index: str(name) for index, name in enumerate(names)}
    )
    expected_ids = list(range(len(raw_names)))
    if sorted(raw_names) != expected_ids:
        raise ValueError("Model class IDs must be contiguous from zero.")

    normalized = {
        class_id: canonicalize_damage_label(name)
        for class_id, name in raw_names.items()
    }
    if len(set(normalized.values())) != len(normalized):
        raise ValueError("Model class names map to duplicate canonical damage classes.")
    return normalized


def shared_model_classes(class_maps: list[dict[int, str]]) -> list[str]:
    shared = set(class_maps[0].values())
    for class_map in class_maps[1:]:
        shared.intersection_update(class_map.values())
    return [name for name in canonical_damage_classes() if name in shared]


def build_comparison_dataset(
    source_config_path: Path,
    source_config: dict[str, Any],
    split: str,
    destination: Path,
    model_names: Any,
    shared_classes: list[str],
) -> Path:
    """Build a local test view with labels remapped to one model's class IDs."""
    source_images = resolve_split_path(source_config_path, source_config, split)
    if destination.exists():
        shutil.rmtree(destination)
    target_images = destination / "images" / split
    target_labels = destination / "labels" / split
    target_images.mkdir(parents=True, exist_ok=True)
    target_labels.mkdir(parents=True, exist_ok=True)

    source_classes = canonical_damage_classes()
    target_names = canonical_model_names(model_names)
    target_ids = {name: class_id for class_id, name in target_names.items()}
    scope = set(shared_classes)

    for source_image in list_images(source_images):
        relative = source_image.relative_to(source_images)
        target_image = target_images / relative
        target_image.parent.mkdir(parents=True, exist_ok=True)
        _hardlink_or_copy(source_image, target_image)

        source_label = _label_path_for_image(source_image)
        target_label = (target_labels / relative).with_suffix(".txt")
        target_label.parent.mkdir(parents=True, exist_ok=True)
        target_label.write_text(
            remap_label_text(source_label, source_classes, target_ids, scope),
            encoding="utf-8",
        )

    config_path = destination / "data.yaml"
    config_path.write_text(
        yaml.safe_dump(
            {
                "path": str(destination.resolve()),
                "train": f"images/{split}",
                "val": f"images/{split}",
                "test": f"images/{split}",
                "names": {index: name for index, name in model_names.items()}
                if isinstance(model_names, dict)
                else {index: name for index, name in enumerate(model_names)},
            },
            sort_keys=False,
        ),
        encoding="utf-8",
    )
    return config_path


def remap_label_text(
    source_label: Path,
    source_classes: list[str],
    target_ids: dict[str, int],
    scope: set[str],
) -> str:
    if not source_label.is_file():
        return ""
    return remap_label_lines(
        source_label.read_text(encoding="utf-8").splitlines(),
        source_classes,
        target_ids,
        scope,
        source=str(source_label),
    )


def remap_label_lines(
    lines: list[str],
    source_classes: list[str],
    target_ids: dict[str, int],
    scope: set[str],
    source: str = "label data",
) -> str:
    remapped: list[str] = []
    for line_number, line in enumerate(lines, start=1):
        values = line.split()
        if not values:
            continue
        try:
            source_id = int(values[0])
            canonical_name = source_classes[source_id]
        except (ValueError, IndexError) as exc:
            raise ValueError(
                f"Invalid class ID at {source}:{line_number}: {values[0]}"
            ) from exc
        if canonical_name in scope:
            remapped.append(" ".join([str(target_ids[canonical_name]), *values[1:]]))
    return "\n".join(remapped) + ("\n" if remapped else "")


def _label_path_for_image(image_path: Path) -> Path:
    parts = list(image_path.parts)
    try:
        image_index = max(
            index for index, part in enumerate(parts) if part.lower() == "images"
        )
    except ValueError as exc:
        raise ValueError(
            f"Expected an 'images' directory in dataset path: {image_path}"
        ) from exc
    parts[image_index] = "labels"
    return Path(*parts).with_suffix(".txt")


def _hardlink_or_copy(source: Path, destination: Path) -> None:
    if destination.exists():
        destination.unlink()
    try:
        os.link(source, destination)
    except OSError:
        shutil.copy2(source, destination)


def _finite_float(value: Any) -> float | None:
    number = float(value)
    return number if math.isfinite(number) else None


def main() -> None:
    evaluate(build_parser().parse_args())


if __name__ == "__main__":
    main()
