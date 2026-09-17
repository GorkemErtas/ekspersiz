from __future__ import annotations

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


def validate_dataset_config(path: Path) -> dict[str, Any]:
    config = load_yaml(path)
    actual_names = _ordered_names(config.get("names"), path)
    expected_names = canonical_damage_classes()
    if actual_names != expected_names:
        raise ValueError(
            "Dataset class order does not match the canonical damage taxonomy. "
            f"Expected {expected_names}, got {actual_names}."
        )

    for split in ("train", "val", "test"):
        if not isinstance(config.get(split), str) or not config[split].strip():
            raise ValueError(f"Dataset config must define a non-empty '{split}' path: {path}")
        split_path = resolve_split_path(path, config, split)
        if not split_path.is_dir():
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
    root_value = config.get("path", ".")
    root = Path(root_value)
    if not root.is_absolute():
        root = (config_path.parent / root).resolve()
    split_path = Path(config[split])
    return split_path if split_path.is_absolute() else root / split_path


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
