from pathlib import Path

import torch
from ultralytics import YOLO


PROJECT_ROOT = Path(__file__).resolve().parent.parent

DATASET_YAML = (
        PROJECT_ROOT
        / "datasets"
        / "vehicle_part"
        / "data.yaml"
)

TRAINING_RUNS_DIR = (
        PROJECT_ROOT
        / "training-runs"
)

BASE_MODEL_PATH = (
        PROJECT_ROOT
        / "yolo11n.pt"
)


def main() -> None:
    if not DATASET_YAML.is_file():
        raise FileNotFoundError(
            f"Dataset YAML bulunamadı: {DATASET_YAML}"
        )

    if not BASE_MODEL_PATH.is_file():
        raise FileNotFoundError(
            f"Başlangıç YOLO modeli bulunamadı: "
            f"{BASE_MODEL_PATH}"
        )

    TRAINING_RUNS_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    device: int | str

    if torch.cuda.is_available():
        device = 0

        print(
            "GPU kullanılıyor:",
            torch.cuda.get_device_name(0),
        )
    else:
        device = "cpu"

        print(
            "CUDA bulunamadı. CPU kullanılacak."
        )

    print(
        "Dataset YAML:",
        DATASET_YAML,
    )

    print(
        "Eğitim çıktısı:",
        TRAINING_RUNS_DIR,
    )

    print(
        "Device:",
        device,
    )

    model = YOLO(
        str(BASE_MODEL_PATH)
    )

    model.train(
        data=str(DATASET_YAML),
        epochs=40,
        imgsz=640,
        batch=8,
        device=device,
        workers=2,
        patience=10,
        project=str(TRAINING_RUNS_DIR),
        name="vehicle_part_v1",
        pretrained=True,
        cache=False,
        plots=True,
        exist_ok=False,
    )


if __name__ == "__main__":
    main()