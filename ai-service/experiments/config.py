from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any

import yaml


AI_SERVICE_ROOT = Path(__file__).resolve().parent.parent
TAXONOMY_PATH = AI_SERVICE_ROOT / "config" / "damage_taxonomy.yaml"
SUPPORTED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def load_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"Configuration not found: {path}")
    with path.open("r", encoding="utf-8") as stream:
        value = yaml.safe_load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"Expected a YAML mapping: {path}")
    return value


def canonical_damage_classes() -> list[str]:
    return _ordered_names(load_yaml(TAXONOMY_PATH).get("names"), TAXONOMY_PATH)


def canonicalize_damage_label(value: str) -> str:
    taxonomy = load_yaml(TAXONOMY_PATH)
    normalized = value.strip().lower().replace(" ", "_")
    aliases = taxonomy.get("aliases", {})
    mapped = aliases.get(normalized, normalized.upper())
    if mapped not in canonical_damage_classes():
        raise ValueError(f"Unmapped damage class: {value}")
    return mapped


def dataset_class_names(config: dict[str, Any], source: Path) -> list[str]:
    return _ordered_names(config.get("names"), source)


def validate_dataset_config(
    path: Path,
    *,
    require_split_dirs: bool = True,
) -> dict[str, Any]:
    config = load_yaml(path)
    actual_names = dataset_class_names(config, path)
    canonical_names = canonical_damage_classes()
    unknown_names = [name for name in actual_names if name not in canonical_names]
    if unknown_names:
        raise ValueError(
            f"Dataset contains classes outside the canonical damage taxonomy: "
            f"{unknown_names}."
        )
    if len(actual_names) != len(set(actual_names)):
        raise ValueError(f"Dataset class names must be unique: {path}")

    for split in ("train", "val", "test"):
        if not isinstance(config.get(split), str) or not config[split].strip():
            raise ValueError(f"Dataset config must define a non-empty '{split}' path: {path}")
        split_path = resolve_split_path(path, config, split)
        if require_split_dirs and not split_path.is_dir():
            raise FileNotFoundError(f"Dataset '{split}' directory not found: {split_path}")
    return config


def validate_class_remap(path: Path) -> dict[str, str]:
    return validate_class_remap_config(load_yaml(path))


def validate_class_remap_config(config: dict[str, Any]) -> dict[str, str]:
    if config.get("unmapped_class_policy") != "reject":
        raise ValueError("External class remaps must reject unmapped source classes.")
    mappings = config.get("mappings")
    if not isinstance(mappings, dict):
        raise ValueError("External class remap 'mappings' must be a YAML mapping.")
    canonical = set(canonical_damage_classes())
    normalized: dict[str, str] = {}
    for source, target in mappings.items():
        if not isinstance(source, str) or not source.strip():
            raise ValueError("Every source class in a remap must be a non-empty string.")
        if not isinstance(target, str) or target.strip().upper() not in canonical:
            raise ValueError(f"Invalid canonical target for source class '{source}': {target}")
        normalized[source.strip()] = target.strip().upper()
    return normalized


def resolve_split_path(config_path: Path, config: dict[str, Any], split: str) -> Path:
    root_value = config.get("path")
    if root_value is None:
        root = config_path.resolve().parent
    else:
        if not isinstance(root_value, str) or not root_value.strip():
            raise ValueError(f"Dataset 'path' must be a non-empty string: {config_path}")
        root = Path(root_value).expanduser()
        if not root.is_absolute():
            raise ValueError(
                "Relative dataset 'path' values depend on the process working directory "
                f"in Ultralytics. Omit 'path' to anchor splits to the YAML directory: "
                f"{config_path}"
            )
        root = root.resolve()
    split_path = Path(config[split])
    return split_path.resolve() if split_path.is_absolute() else (root / split_path).resolve()


def list_images(directory: Path) -> list[Path]:
    if not directory.is_dir():
        raise FileNotFoundError(f"Image directory not found: {directory}")
    return sorted(
        path
        for path in directory.rglob("*")
        if path.is_file() and path.suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS
    )


def require_training_images(config_path: Path, config: dict[str, Any]) -> None:
    for split in ("train", "val"):
        directory = resolve_split_path(config_path, config, split)
        if not list_images(directory):
            raise ValueError(
                f"Dataset '{split}' split contains no supported images: {directory}. "
                "Populate the dataset manually before training."
            )


def validate_detection_dataset(
    config_path: Path,
    config: dict[str, Any],
) -> dict[str, Any]:
    """Validate YOLO detection pairs and labels for every configured split."""
    names = dataset_class_names(config, config_path)
    class_counts = {name: 0 for name in names}
    image_counts: dict[str, int] = {}
    annotation_counts: dict[str, int] = {}

    for split in ("train", "val", "test"):
        images_root = resolve_split_path(config_path, config, split)
        labels_root = _labels_root_for_images(images_root)
        images = _relative_files(images_root, SUPPORTED_IMAGE_EXTENSIONS)
        labels = _relative_files(labels_root, {".txt"})
        missing_labels = sorted(set(images) - set(labels))
        missing_images = sorted(set(labels) - set(images))
        if missing_labels:
            raise ValueError(
                f"Dataset '{split}' is missing labels for {len(missing_labels)} image(s); "
                f"first: {missing_labels[0]}."
            )
        if missing_images:
            raise ValueError(
                f"Dataset '{split}' is missing images for {len(missing_images)} label(s); "
                f"first: {missing_images[0]}."
            )

        split_annotations = 0
        for label_path in labels.values():
            for line_number, line in enumerate(
                label_path.read_text(encoding="utf-8-sig").splitlines(), start=1
            ):
                if not line.strip():
                    continue
                values = line.split()
                if len(values) != 5:
                    raise ValueError(
                        f"Malformed detection annotation at {label_path}:{line_number}; "
                        f"expected 5 fields, found {len(values)}."
                    )
                try:
                    class_id = int(values[0])
                except ValueError as exc:
                    raise ValueError(
                        f"Invalid class ID at {label_path}:{line_number}: {values[0]}"
                    ) from exc
                if not 0 <= class_id < len(names):
                    raise ValueError(
                        f"Class ID {class_id} at {label_path}:{line_number} is outside "
                        f"the configured range 0..{len(names) - 1}."
                    )
                coordinates = _normalized_detection_coordinates(
                    values[1:], label_path, line_number
                )
                if coordinates[2] <= 0.0 or coordinates[3] <= 0.0:
                    raise ValueError(
                        f"Detection width and height must be greater than zero at "
                        f"{label_path}:{line_number}."
                    )
                class_counts[names[class_id]] += 1
                split_annotations += 1

        image_counts[split] = len(images)
        annotation_counts[split] = split_annotations

    return {
        "classes": names,
        "images_per_split": image_counts,
        "annotations_per_split": annotation_counts,
        "total_images": sum(image_counts.values()),
        "total_annotations": sum(annotation_counts.values()),
        "per_class_annotations": class_counts,
    }


def parse_model_spec(value: str) -> tuple[str, Path]:
    if "=" not in value:
        raise ValueError("Model must use LABEL=PATH format.")
    label, raw_path = value.split("=", 1)
    label = label.strip()
    path = Path(raw_path.strip()).expanduser()
    if not label or not raw_path.strip():
        raise ValueError("Model must use a non-empty LABEL=PATH value.")
    if not path.is_absolute():
        path = (AI_SERVICE_ROOT / path).resolve()
    if not path.is_file():
        raise FileNotFoundError(f"Model '{label}' not found: {path}")
    return safe_name(label), path


def safe_name(value: str) -> str:
    normalized = re.sub(r"[^a-zA-Z0-9._-]+", "-", value.strip()).strip("-.")
    if not normalized:
        raise ValueError("A safe, non-empty experiment label is required.")
    return normalized


def select_device(requested: str) -> int | str:
    if requested != "auto":
        return int(requested) if requested.isdigit() else requested

    import torch

    if torch.cuda.is_available():
        print(f"CUDA device: {torch.cuda.get_device_name(0)}")
        return 0
    print("CUDA is unavailable; using CPU.")
    return "cpu"


def _labels_root_for_images(images_root: Path) -> Path:
    parts = list(images_root.parts)
    try:
        images_index = max(
            index for index, part in enumerate(parts) if part.lower() == "images"
        )
    except ValueError as exc:
        raise ValueError(
            f"Dataset split path must contain an 'images' directory: {images_root}"
        ) from exc
    parts[images_index] = "labels"
    labels_root = Path(*parts)
    if not labels_root.is_dir():
        raise FileNotFoundError(f"Dataset label directory not found: {labels_root}")
    return labels_root


def _relative_files(directory: Path, extensions: set[str]) -> dict[str, Path]:
    files: dict[str, Path] = {}
    for path in sorted(directory.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in extensions:
            continue
        key = str(path.relative_to(directory).with_suffix("")).lower()
        if key in files:
            raise ValueError(
                f"Multiple dataset files share the same relative stem: {files[key]}, {path}"
            )
        files[key] = path
    return files


def _normalized_detection_coordinates(
    raw_values: list[str],
    label_path: Path,
    line_number: int,
) -> list[float]:
    coordinates: list[float] = []
    for value in raw_values:
        try:
            coordinate = float(value)
        except ValueError as exc:
            raise ValueError(
                f"Invalid detection coordinate at {label_path}:{line_number}: {value}"
            ) from exc
        if not math.isfinite(coordinate) or not 0.0 <= coordinate <= 1.0:
            raise ValueError(
                f"Detection coordinate must be normalized to [0, 1] at "
                f"{label_path}:{line_number}: {value}"
            )
        coordinates.append(coordinate)
    return coordinates


def _ordered_names(value: Any, source: Path) -> list[str]:
    if isinstance(value, list):
        names = value
    elif isinstance(value, dict):
        try:
            indexed = {int(key): item for key, item in value.items()}
        except (TypeError, ValueError) as exc:
            raise ValueError(f"Class IDs must be integers: {source}") from exc
        expected_ids = list(range(len(indexed)))
        if sorted(indexed) != expected_ids:
            raise ValueError(f"Class IDs must be contiguous from zero: {source}")
        names = [indexed[index] for index in expected_ids]
    else:
        raise ValueError(f"A class-name list or mapping is required: {source}")

    if not all(isinstance(name, str) and name.strip() for name in names):
        raise ValueError(f"Every class name must be a non-empty string: {source}")
    return [name.strip().upper() for name in names]
