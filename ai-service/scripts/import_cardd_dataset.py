from __future__ import annotations

import argparse
import json
import math
import shutil
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from experiments.config import (  # noqa: E402
    SUPPORTED_IMAGE_EXTENSIONS,
    canonical_damage_classes,
    dataset_class_names,
    load_yaml,
    validate_dataset_config,
)


DEFAULT_SOURCE = PROJECT_ROOT / "datasets" / "raw" / "cardd"
DEFAULT_TARGET = PROJECT_ROOT / "datasets" / "vehicle_damage_detection_v2"
DEFAULT_MAPPING = PROJECT_ROOT / "config" / "cardd_import.yaml"
SPLITS = ("train", "val", "test")
SOURCE_NAME = "cardd"
REPORT_NAME = "cardd-import-report.json"


class CarddImportError(ValueError):
    """Raised when the raw CarDD dataset cannot be imported safely."""


@dataclass(frozen=True)
class ImportMapping:
    source_names: dict[int, str]
    model_classes: tuple[str, ...]
    target_ids: dict[int, int | None]
    dropped_class_ids: frozenset[int]


@dataclass(frozen=True)
class PlannedImage:
    split: str
    image_path: Path
    label_path: Path
    remapped_label: str
    annotations_before: int
    annotations_after: int
    dropped_annotations: int
    quarantine_reason: str | None = None


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Import a manually downloaded CarDD YOLO dataset into Detection V2."
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET)
    parser.add_argument("--mapping", type=Path, default=DEFAULT_MAPPING)
    return parser


def load_import_mapping(path: Path) -> ImportMapping:
    config = load_yaml(path.resolve())
    if config.get("source_dataset") != "CarDD":
        raise CarddImportError("CarDD import config must declare source_dataset: CarDD.")
    source_names = _indexed_mapping(config.get("source_names"), "source_names")
    class_mapping = _indexed_mapping(config.get("class_mapping"), "class_mapping")
    if set(source_names) != set(class_mapping):
        raise CarddImportError("CarDD source_names and class_mapping IDs must match.")

    canonical = canonical_damage_classes()
    raw_model_classes = _indexed_mapping(config.get("model_classes"), "model_classes")
    model_classes = tuple(
        str(raw_model_classes[index]).strip().upper()
        for index in raw_model_classes
    )
    if len(model_classes) != len(set(model_classes)):
        raise CarddImportError("CarDD model_classes must be unique.")
    unknown_model_classes = [name for name in model_classes if name not in canonical]
    if unknown_model_classes:
        raise CarddImportError(
            f"CarDD model_classes are outside the application taxonomy: "
            f"{unknown_model_classes}"
        )
    model_ids = {name: index for index, name in enumerate(model_classes)}
    target_ids: dict[int, int | None] = {}
    for source_id, target in class_mapping.items():
        if target is None:
            target_ids[source_id] = None
            continue
        normalized = str(target).strip().upper()
        if normalized not in canonical:
            raise CarddImportError(
                f"CarDD class {source_id} maps to unknown canonical class: {target}"
            )
        if normalized not in model_ids:
            raise CarddImportError(
                f"CarDD class {source_id} maps to canonical class {normalized}, but that "
                "class is absent from this model's output head."
            )
        target_ids[source_id] = model_ids[normalized]

    drop_policy = _indexed_mapping(
        config.get("drop_policy"), "drop_policy", require_contiguous=False
    )
    dropped = frozenset(source_id for source_id, target in target_ids.items() if target is None)
    if set(drop_policy) != set(dropped):
        raise CarddImportError(
            "Every dropped CarDD class must have exactly one explicit drop policy."
        )
    for source_id, policy in drop_policy.items():
        if policy != "quarantine_if_only_annotation":
            raise CarddImportError(
                f"Unsupported drop policy for CarDD class {source_id}: {policy}"
            )
    return ImportMapping(source_names, model_classes, target_ids, dropped)


def remap_annotation_line(
    line: str,
    mapping: ImportMapping,
    source: str,
    line_number: int,
) -> tuple[str | None, int]:
    fields = line.split()
    if len(fields) != 5:
        raise CarddImportError(
            f"Malformed YOLO annotation at {source}:{line_number}; "
            f"expected 5 fields, found {len(fields)}."
        )
    try:
        source_id = int(fields[0])
    except ValueError as exc:
        raise CarddImportError(
            f"Invalid CarDD class ID at {source}:{line_number}: {fields[0]}"
        ) from exc
    if source_id not in mapping.source_names:
        raise CarddImportError(
            f"Unexpected CarDD class ID at {source}:{line_number}: {source_id}"
        )

    coordinate_names = ("x_center", "y_center", "width", "height")
    coordinates: list[float] = []
    for name, raw_value in zip(coordinate_names, fields[1:]):
        try:
            value = float(raw_value)
        except ValueError as exc:
            raise CarddImportError(
                f"Invalid {name} at {source}:{line_number}: {raw_value}"
            ) from exc
        if not math.isfinite(value) or not 0.0 <= value <= 1.0:
            raise CarddImportError(
                f"{name} must be normalized to [0, 1] at "
                f"{source}:{line_number}: {raw_value}"
            )
        coordinates.append(value)
    if coordinates[2] <= 0.0 or coordinates[3] <= 0.0:
        raise CarddImportError(
            f"YOLO width and height must be greater than zero at "
            f"{source}:{line_number}."
        )

    target_id = mapping.target_ids[source_id]
    if target_id is None:
        return None, source_id
    return " ".join([str(target_id), *fields[1:]]), source_id


def import_cardd_dataset(
    source_root: Path = DEFAULT_SOURCE,
    target_root: Path = DEFAULT_TARGET,
    mapping_path: Path = DEFAULT_MAPPING,
) -> dict[str, Any]:
    source_root = source_root.resolve()
    target_root = target_root.resolve()
    _validate_separate_roots(source_root, target_root)
    mapping = load_import_mapping(mapping_path)
    _validate_source_config(source_root, mapping)
    target_config_path = target_root / "data.yaml"
    target_config = validate_dataset_config(
        target_config_path, require_split_dirs=False
    )
    configured_classes = dataset_class_names(target_config, target_config_path)
    if configured_classes != list(mapping.model_classes):
        raise CarddImportError(
            "Detection V2 data.yaml classes do not match the CarDD model output head. "
            f"Expected {list(mapping.model_classes)}, got {configured_classes}."
        )

    plans, validation = _plan_import(source_root, mapping)
    if validation["errors"]:
        details = "\n".join(f"- {message}" for message in validation["errors"])
        raise CarddImportError(
            f"CarDD import validation failed with {len(validation['errors'])} error(s):\n"
            f"{details}"
        )

    report = _build_report(source_root, target_root, plans, validation, mapping)
    _write_staging_output(target_root, plans, report)
    _replace_generated_output(target_root)
    return report


def _plan_import(
    source_root: Path,
    mapping: ImportMapping,
) -> tuple[list[PlannedImage], dict[str, Any]]:
    plans: list[PlannedImage] = []
    errors: list[str] = []
    malformed_labels = 0
    missing_pairs = 0

    for split in SPLITS:
        images_dir = source_root / split / "images"
        labels_dir = source_root / split / "labels"
        if not images_dir.is_dir() or not labels_dir.is_dir():
            errors.append(
                f"Missing CarDD split directories: {images_dir} and/or {labels_dir}"
            )
            continue

        images, duplicate_images = _files_by_stem(images_dir, SUPPORTED_IMAGE_EXTENSIONS)
        labels, duplicate_labels = _files_by_stem(labels_dir, {".txt"})
        for stem in duplicate_images:
            errors.append(f"Multiple images share stem '{stem}' in split '{split}'.")
            missing_pairs += 1
        for stem in duplicate_labels:
            errors.append(f"Multiple labels share stem '{stem}' in split '{split}'.")
            missing_pairs += 1

        for stem in sorted(set(images) - set(labels)):
            errors.append(f"Missing label for {split} image: {images[stem].name}")
            missing_pairs += 1
        for stem in sorted(set(labels) - set(images)):
            errors.append(f"Missing image for {split} label: {labels[stem].name}")
            missing_pairs += 1

        for stem in sorted(set(images) & set(labels)):
            image_path = images[stem]
            label_path = labels[stem]
            remapped: list[str] = []
            dropped = 0
            before = 0
            label_failed = False
            for line_number, line in enumerate(
                label_path.read_text(encoding="utf-8-sig").splitlines(), start=1
            ):
                if not line.strip():
                    continue
                before += 1
                try:
                    converted, source_id = remap_annotation_line(
                        line, mapping, str(label_path), line_number
                    )
                except CarddImportError as exc:
                    errors.append(str(exc))
                    malformed_labels += 1
                    label_failed = True
                    continue
                if source_id in mapping.dropped_class_ids:
                    dropped += 1
                elif converted is not None:
                    remapped.append(converted)
            if label_failed:
                continue

            quarantine_reason = None
            if before > 0 and dropped == before:
                quarantine_reason = "TIRE_FLAT_ONLY"
            plans.append(
                PlannedImage(
                    split=split,
                    image_path=image_path,
                    label_path=label_path,
                    remapped_label="\n".join(remapped) + ("\n" if remapped else ""),
                    annotations_before=before,
                    annotations_after=len(remapped),
                    dropped_annotations=dropped,
                    quarantine_reason=quarantine_reason,
                )
            )

    return plans, {
        "errors": errors,
        "malformed_labels": malformed_labels,
        "missing_image_label_pairs": missing_pairs,
    }


def _build_report(
    source_root: Path,
    target_root: Path,
    plans: list[PlannedImage],
    validation: dict[str, Any],
    mapping: ImportMapping,
) -> dict[str, Any]:
    imported_per_split = {split: 0 for split in SPLITS}
    processed_per_split = {split: 0 for split in SPLITS}
    class_counts: Counter[int] = Counter()
    quarantine: list[dict[str, str]] = []

    for plan in plans:
        processed_per_split[plan.split] += 1
        if plan.quarantine_reason:
            quarantine.append(
                {
                    "split": plan.split,
                    "image": plan.image_path.name,
                    "label": plan.label_path.name,
                    "reason": plan.quarantine_reason,
                }
            )
            continue
        imported_per_split[plan.split] += 1
        for line in plan.remapped_label.splitlines():
            class_counts[int(line.split()[0])] += 1

    return {
        "source_dataset": "CarDD",
        "application_taxonomy": canonical_damage_classes(),
        "model_classes": list(mapping.model_classes),
        "source_root": str(source_root),
        "target_root": str(target_root),
        "total_images_processed": len(plans),
        "images_processed_per_split": processed_per_split,
        "images_imported_per_split": imported_per_split,
        "total_images_imported": sum(imported_per_split.values()),
        "annotations_before_remapping": sum(p.annotations_before for p in plans),
        "annotations_after_remapping": sum(p.annotations_after for p in plans),
        "tire_flat_annotations_dropped": sum(p.dropped_annotations for p in plans),
        "tire_flat_only_images_quarantined": len(quarantine),
        "malformed_labels": validation["malformed_labels"],
        "missing_image_label_pairs": validation["missing_image_label_pairs"],
        "per_class_counts_after_remapping": {
            name: class_counts[index]
            for index, name in enumerate(mapping.model_classes)
        },
        "quarantined_images": quarantine,
    }


def _write_staging_output(
    target_root: Path,
    plans: list[PlannedImage],
    report: dict[str, Any],
) -> None:
    staging = target_root / ".cardd-import-staging"
    if staging.exists():
        shutil.rmtree(staging)
    try:
        for split in SPLITS:
            (staging / "images" / split / SOURCE_NAME).mkdir(parents=True)
            (staging / "labels" / split / SOURCE_NAME).mkdir(parents=True)
        for plan in plans:
            if plan.quarantine_reason:
                image_destination = (
                    staging / "quarantine" / plan.split / "images" / plan.image_path.name
                )
                label_destination = (
                    staging / "quarantine" / plan.split / "labels" / plan.label_path.name
                )
                image_destination.parent.mkdir(parents=True, exist_ok=True)
                label_destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(plan.image_path, image_destination)
                shutil.copy2(plan.label_path, label_destination)
                continue

            image_destination = (
                staging / "images" / plan.split / SOURCE_NAME / plan.image_path.name
            )
            label_destination = (
                staging / "labels" / plan.split / SOURCE_NAME / f"{plan.image_path.stem}.txt"
            )
            shutil.copy2(plan.image_path, image_destination)
            label_destination.write_text(plan.remapped_label, encoding="utf-8")

        (staging / REPORT_NAME).write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        raise


def _replace_generated_output(target_root: Path) -> None:
    staging = target_root / ".cardd-import-staging"
    for split in SPLITS:
        for kind in ("images", "labels"):
            destination = target_root / kind / split / SOURCE_NAME
            if destination.exists():
                shutil.rmtree(destination)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(staging / kind / split / SOURCE_NAME), str(destination))

    quarantine = target_root / "quarantine" / SOURCE_NAME
    if quarantine.exists():
        shutil.rmtree(quarantine)
    staged_quarantine = staging / "quarantine"
    if staged_quarantine.exists():
        quarantine.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(staged_quarantine), str(quarantine))
    else:
        quarantine.mkdir(parents=True, exist_ok=True)

    shutil.move(str(staging / REPORT_NAME), str(target_root / REPORT_NAME))
    shutil.rmtree(staging)


def _validate_source_config(source_root: Path, mapping: ImportMapping) -> None:
    config_path = source_root / "data.yaml"
    config = load_yaml(config_path)
    actual_names = config.get("names")
    if isinstance(actual_names, list):
        ordered = {index: str(name).strip() for index, name in enumerate(actual_names)}
    elif isinstance(actual_names, dict):
        try:
            ordered = {
                int(index): str(name).strip() for index, name in actual_names.items()
            }
        except (TypeError, ValueError) as exc:
            raise CarddImportError(
                f"CarDD data.yaml class IDs must be integers: {config_path}"
            ) from exc
    else:
        raise CarddImportError(f"CarDD data.yaml has no valid names list: {config_path}")
    if ordered != mapping.source_names:
        raise CarddImportError(
            "CarDD data.yaml class names/order do not match config/cardd_import.yaml. "
            f"Expected {mapping.source_names}, got {ordered}."
        )


def _validate_separate_roots(source_root: Path, target_root: Path) -> None:
    if not source_root.is_dir():
        raise FileNotFoundError(f"CarDD source directory not found: {source_root}")
    if not target_root.is_dir():
        raise FileNotFoundError(f"Detection V2 target directory not found: {target_root}")
    if (
        source_root == target_root
        or source_root in target_root.parents
        or target_root in source_root.parents
    ):
        raise CarddImportError("CarDD source and Detection V2 target must be separate trees.")


def _indexed_mapping(
    value: Any,
    name: str,
    require_contiguous: bool = True,
) -> dict[int, Any]:
    if not isinstance(value, dict):
        raise CarddImportError(f"CarDD import config '{name}' must be a mapping.")
    try:
        indexed = {int(key): item for key, item in value.items()}
    except (TypeError, ValueError) as exc:
        raise CarddImportError(f"CarDD import config '{name}' IDs must be integers.") from exc
    if require_contiguous and sorted(indexed) != list(range(len(indexed))):
        raise CarddImportError(
            f"CarDD import config '{name}' IDs must be contiguous from zero."
        )
    return indexed


def _files_by_stem(
    directory: Path,
    extensions: set[str],
) -> tuple[dict[str, Path], set[str]]:
    files: dict[str, Path] = {}
    duplicates: set[str] = set()
    for path in sorted(directory.iterdir()):
        if not path.is_file() or path.suffix.lower() not in extensions:
            continue
        key = path.stem.lower()
        if key in files:
            duplicates.add(key)
        else:
            files[key] = path
    return files, duplicates


def main() -> None:
    args = build_parser().parse_args()
    try:
        report = import_cardd_dataset(args.source, args.target, args.mapping)
    except (OSError, ValueError) as exc:
        print(f"CarDD import failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
    summary = {key: value for key, value in report.items() if key != "quarantined_images"}
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"Import report: {(args.target.resolve() / REPORT_NAME)}")


if __name__ == "__main__":
    main()
