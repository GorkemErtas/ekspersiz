from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from experiments.config import (  # noqa: E402
    require_training_images,
    safe_name,
    select_device,
    validate_dataset_config,
)


DEFAULT_DATA = PROJECT_ROOT / "datasets" / "vehicle_damage_segmentation_v1" / "data.yaml"
DEFAULT_MODEL = PROJECT_ROOT / "yolo11n-seg.pt"
DEFAULT_PROJECT = PROJECT_ROOT / "training-runs"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Train the experimental EksperSiz Damage Segmentation V1 model."
    )
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--project", type=Path, default=DEFAULT_PROJECT)
    parser.add_argument("--name", default="damage-segmentation-v1")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--patience", type=int, default=18)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--workers", type=int)
    parser.add_argument("--device", default="auto", help="auto, cpu, 0, 1, ...")
    return parser


def train_damage_segmentation(args: argparse.Namespace) -> None:
    data_path = args.data.resolve()
    model_path = args.model.resolve()
    if not model_path.is_file():
        raise FileNotFoundError(
            "Pretrained segmentation model not found. Place yolo11n-seg.pt in "
            f"ai-service or pass --model explicitly: {model_path}"
        )

    dataset = validate_dataset_config(data_path)
    require_training_images(data_path, dataset)
    device = select_device(args.device)
    workers = args.workers if args.workers is not None else (2 if device != "cpu" else 0)
    args.project.mkdir(parents=True, exist_ok=True)

    print(f"Dataset: {data_path}")
    print(f"Base model: {model_path}")
    print(f"Output: {args.project.resolve() / safe_name(args.name)}")
    print(f"Device: {device}")

    from ultralytics import YOLO

    model = YOLO(str(model_path))
    model.train(
        data=str(data_path),
        epochs=args.epochs,
        batch=args.batch,
        imgsz=args.imgsz,
        patience=args.patience,
        seed=args.seed,
        deterministic=True,
        device=device,
        workers=workers,
        project=str(args.project.resolve()),
        name=safe_name(args.name),
        pretrained=True,
        cache=False,
        plots=True,
        val=True,
        exist_ok=False,
    )


def main() -> None:
    train_damage_segmentation(build_parser().parse_args())


if __name__ == "__main__":
    main()

