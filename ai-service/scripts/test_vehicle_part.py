from pathlib import Path

from ultralytics import YOLO


PROJECT_ROOT = Path(__file__).resolve().parent.parent

MODEL_PATH = (
        PROJECT_ROOT
        / "training-runs"
        / "vehicle_part_v1"
        / "weights"
        / "best.pt"
)

TEST_IMAGES_DIR = (
        PROJECT_ROOT
        / "datasets"
        / "vehicle_part"
        / "images"
        / "test"
)

OUTPUT_DIR = (
        PROJECT_ROOT
        / "prediction-runs"
)

SUPPORTED_IMAGE_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
}


def main() -> None:
    if not MODEL_PATH.is_file():
        raise FileNotFoundError(
            f"Model bulunamadı: {MODEL_PATH}"
        )

    if not TEST_IMAGES_DIR.is_dir():
        raise FileNotFoundError(
            f"Test klasörü bulunamadı: "
            f"{TEST_IMAGES_DIR}"
        )

    test_images = [
        file_path
        for file_path in TEST_IMAGES_DIR.iterdir()
        if (
                file_path.is_file()
                and file_path.suffix.lower()
                in SUPPORTED_IMAGE_EXTENSIONS
        )
    ]

    if not test_images:
        raise FileNotFoundError(
            "Test klasöründe desteklenen bir görsel "
            f"bulunamadı: {TEST_IMAGES_DIR}"
        )

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    print(
        "Model:",
        MODEL_PATH.resolve(),
    )

    print(
        "Test klasörü:",
        TEST_IMAGES_DIR.resolve(),
    )

    print(
        "Test görseli sayısı:",
        len(test_images),
    )

    print(
        "Çıktı klasörü:",
        OUTPUT_DIR.resolve(),
    )

    model = YOLO(
        str(MODEL_PATH)
    )

    model.predict(
        source=str(TEST_IMAGES_DIR),
        conf=0.25,
        iou=0.50,
        imgsz=640,
        save=True,
        project=str(OUTPUT_DIR),
        name="vehicle_part_test",
        exist_ok=True,
        verbose=True,
    )


if __name__ == "__main__":
    main()