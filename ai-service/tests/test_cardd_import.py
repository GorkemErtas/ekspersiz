import json
import shutil
import unittest
from pathlib import Path

import yaml

from experiments.config import (
    AI_SERVICE_ROOT,
    validate_dataset_config,
    validate_detection_dataset,
)
from scripts.import_cardd_dataset import (
    CarddImportError,
    import_cardd_dataset,
    load_import_mapping,
    remap_annotation_line,
)


class CarddAnnotationRemappingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mapping = load_import_mapping(
            AI_SERVICE_ROOT / "config" / "cardd_import.yaml"
        )

    def test_each_supported_cardd_class_maps_to_five_class_model_id(self) -> None:
        expected = {0: 1, 1: 0, 2: 2, 3: 4, 4: 3}
        for source_id, target_id in expected.items():
            with self.subTest(source_id=source_id):
                converted, parsed_source_id = remap_annotation_line(
                    f"{source_id} 0.5 0.5 0.2 0.3",
                    self.mapping,
                    "sample.txt",
                    1,
                )
                self.assertEqual(source_id, parsed_source_id)
                self.assertEqual(
                    f"{target_id} 0.5 0.5 0.2 0.3",
                    converted,
                )

    def test_tire_flat_annotation_is_dropped(self) -> None:
        converted, source_id = remap_annotation_line(
            "5 0.5 0.5 0.2 0.3",
            self.mapping,
            "sample.txt",
            1,
        )
        self.assertEqual(5, source_id)
        self.assertIsNone(converted)

    def test_malformed_annotation_is_rejected(self) -> None:
        invalid_lines = (
            "0 0.5 0.5 0.2",
            "0 1.1 0.5 0.2 0.3",
            "0 0.5 0.5 0 0.3",
            "0 nan 0.5 0.2 0.3",
        )
        for line in invalid_lines:
            with self.subTest(line=line), self.assertRaises(CarddImportError):
                remap_annotation_line(line, self.mapping, "sample.txt", 1)

    def test_unexpected_class_is_rejected(self) -> None:
        with self.assertRaisesRegex(CarddImportError, "Unexpected CarDD class ID"):
            remap_annotation_line(
                "6 0.5 0.5 0.2 0.3",
                self.mapping,
                "sample.txt",
                1,
            )


class CarddImportIntegrationTest(unittest.TestCase):
    workspace = AI_SERVICE_ROOT / "tests" / ".cardd-import-test-workspace"

    def setUp(self) -> None:
        self._remove_workspace()
        self.source = self.workspace / "raw" / "cardd"
        self.target = self.workspace / "vehicle_damage_detection_v2"
        for split in ("train", "val", "test"):
            (self.source / split / "images").mkdir(parents=True)
            (self.source / split / "labels").mkdir(parents=True)
            (self.target / "images" / split).mkdir(parents=True)
            (self.target / "labels" / split).mkdir(parents=True)
        (self.source / "data.yaml").write_text(
            yaml.safe_dump(
                {
                    "names": [
                        "dent",
                        "scratch",
                        "crack",
                        "glass shatter",
                        "lamp broken",
                        "tire flat",
                    ]
                },
                sort_keys=False,
            ),
            encoding="utf-8",
        )
        shutil.copy2(
            AI_SERVICE_ROOT / "datasets" / "vehicle_damage_detection_v2" / "data.yaml",
            self.target / "data.yaml",
        )

    def tearDown(self) -> None:
        self._remove_workspace()

    def test_mixed_tire_flat_and_supported_damage_keeps_supported_damage(self) -> None:
        self._add_pair(
            "train",
            "mixed",
            "5 0.5 0.5 0.2 0.2\n1 0.4 0.4 0.1 0.1\n",
        )

        report = self._run_import()

        imported_label = self.target / "labels" / "train" / "cardd" / "mixed.txt"
        self.assertEqual("0 0.4 0.4 0.1 0.1\n", imported_label.read_text())
        self.assertTrue(
            (self.target / "images" / "train" / "cardd" / "mixed.jpg").is_file()
        )
        self.assertEqual(1, report["tire_flat_annotations_dropped"])
        self.assertEqual(0, report["tire_flat_only_images_quarantined"])
        self.assertEqual(
            ["SCRATCH", "DENT", "CRACK", "BROKEN_PART", "BROKEN_GLASS"],
            report["model_classes"],
        )

    def test_tire_flat_only_image_is_quarantined(self) -> None:
        self._add_pair("val", "tire_only", "5 0.5 0.5 0.2 0.2\n")

        report = self._run_import()

        self.assertFalse(
            (self.target / "images" / "val" / "cardd" / "tire_only.jpg").exists()
        )
        self.assertTrue(
            (
                self.target
                / "quarantine"
                / "cardd"
                / "val"
                / "images"
                / "tire_only.jpg"
            ).is_file()
        )
        self.assertEqual(1, report["tire_flat_only_images_quarantined"])
        self.assertEqual("TIRE_FLAT_ONLY", report["quarantined_images"][0]["reason"])

    def test_validation_failure_does_not_replace_existing_output(self) -> None:
        self._add_pair("train", "broken", "9 0.5 0.5 0.2 0.2\n")
        existing = self.target / "images" / "train" / "cardd" / "existing.jpg"
        existing.parent.mkdir(parents=True)
        existing.write_bytes(b"existing")

        with self.assertRaisesRegex(CarddImportError, "Unexpected CarDD class ID"):
            self._run_import()

        self.assertEqual(b"existing", existing.read_bytes())

    def test_rerun_replaces_only_cardd_output_without_stale_files(self) -> None:
        self._add_pair("test", "one", "0 0.5 0.5 0.2 0.2\n")
        raw_image = self.source / "test" / "images" / "one.jpg"
        raw_before = raw_image.read_bytes()
        first_report = self._run_import()

        stale = self.target / "images" / "test" / "cardd" / "stale.jpg"
        stale.write_bytes(b"stale")
        unrelated = self.target / "images" / "test" / "manual.jpg"
        unrelated.write_bytes(b"manual")
        second_report = self._run_import()

        self.assertEqual(first_report, second_report)
        self.assertFalse(stale.exists())
        self.assertEqual(b"manual", unrelated.read_bytes())
        self.assertEqual(raw_before, raw_image.read_bytes())
        report_file = self.target / "cardd-import-report.json"
        self.assertEqual(second_report, json.loads(report_file.read_text(encoding="utf-8")))

    def test_missing_image_label_pair_is_rejected(self) -> None:
        (self.source / "train" / "labels" / "orphan.txt").write_text(
            "0 0.5 0.5 0.2 0.2\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(CarddImportError, "Missing image"):
            self._run_import()

    def test_training_validation_rejects_class_id_outside_five_class_head(self) -> None:
        self._add_pair("train", "invalid_later", "2 0.5 0.5 0.2 0.2\n")
        self._run_import()
        generated_label = (
            self.target / "labels" / "train" / "cardd" / "invalid_later.txt"
        )
        generated_label.write_text("5 0.5 0.5 0.2 0.2\n", encoding="utf-8")
        config_path = self.target / "data.yaml"
        config = validate_dataset_config(config_path)

        with self.assertRaisesRegex(ValueError, "configured range 0..4"):
            validate_detection_dataset(config_path, config)

    def _add_pair(self, split: str, stem: str, labels: str) -> None:
        (self.source / split / "images" / f"{stem}.jpg").write_bytes(b"image")
        (self.source / split / "labels" / f"{stem}.txt").write_text(
            labels,
            encoding="utf-8",
        )

    def _run_import(self) -> dict:
        return import_cardd_dataset(
            self.source,
            self.target,
            AI_SERVICE_ROOT / "config" / "cardd_import.yaml",
        )

    def _remove_workspace(self) -> None:
        if self.workspace.exists():
            shutil.rmtree(self.workspace)


if __name__ == "__main__":
    unittest.main()
