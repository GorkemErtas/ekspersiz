from pathlib import Path

from ultralytics import YOLO


PROJECT_ROOT = Path(__file__).resolve().parent.parent

MODEL_PATH = (
        PROJECT_ROOT
        / "training-runs"
        / "vehicle_damage_type_v1"
        / "weights"
        / "best.pt"
)

TEST_IMAGE_PATH = (
        PROJECT_ROOT
        / "test-images"
        / "carsc.jpg"
)

OUTPUT_PATH = (
        PROJECT_ROOT
        / "prediction-runs"
)


def test_damage_model() -> None:
    if not MODEL_PATH.is_file():
        raise FileNotFoundError(
            f"Model was not found: {MODEL_PATH}"
        )

    if not TEST_IMAGE_PATH.is_file():
        raise FileNotFoundError(
            f"Test image was not found: {TEST_IMAGE_PATH}"
        )

    OUTPUT_PATH.mkdir(
        parents=True,
        exist_ok=True,
    )

    print(
        "Model path:",
        MODEL_PATH.resolve(),
    )

    print(
        "Test image:",
        TEST_IMAGE_PATH.resolve(),
    )

    print(
        "Output path:",
        OUTPUT_PATH.resolve(),
    )

    model = YOLO(
        str(MODEL_PATH)
    )

    results = model.predict(
        source=str(TEST_IMAGE_PATH),
        conf=0.25,
        iou=0.45,
        max_det=20,
        save=True,
        project=str(OUTPUT_PATH),
        name="damage-test",
        exist_ok=True,
        verbose=True,
    )

    total_detection_count = 0

    for result in results:
        if result.boxes is None:
            continue

        total_detection_count += len(
            result.boxes
        )

        for box in result.boxes:
            class_id = int(
                box.cls[0].item()
            )

            confidence = float(
                box.conf[0].item()
            )

            print(
                f"Class: "
                f"{result.names[class_id]}, "
                f"confidence: "
                f"{confidence:.4f}"
            )

    print(
        "Total detected boxes:",
        total_detection_count,
    )

    if total_detection_count == 0:
        print(
            "No damage detection was produced."
        )


if __name__ == "__main__":
    test_damage_model()