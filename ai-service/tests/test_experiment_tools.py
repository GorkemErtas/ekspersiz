import shutil
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from experiments.config import (
    AI_SERVICE_ROOT,
    canonical_damage_classes,
    canonicalize_damage_label,
    dataset_class_names,
    resolve_split_path,
    validate_class_remap_config,
    validate_dataset_config,
)
from scripts.analyze_damage_errors import review_flags
from scripts.evaluate_damage_models import (
    canonical_model_names,
    metric_report,
    remap_label_lines,
    shared_model_classes,
)
from scripts.train_damage_model import build_parser as build_detection_train_parser


class ExperimentConfigurationTest(unittest.TestCase):
    def test_application_taxonomy_remains_seven_classes(self) -> None:
        expected = [
            "SCRATCH",
            "DENT",
            "PAINT_DAMAGE",
            "CRACK",
            "BROKEN_PART",
            "BROKEN_GLASS",
            "DEFORMATION",
        ]
        self.assertEqual(expected, canonical_damage_classes())
        self.assertNotIn("NO_VISIBLE_DAMAGE", expected)

        detection_config = (
            AI_SERVICE_ROOT / "datasets" / "vehicle_damage_detection_v2" / "data.yaml"
        )
        detection = validate_dataset_config(detection_config)
        self.assertEqual(
            ["SCRATCH", "DENT", "CRACK", "BROKEN_PART", "BROKEN_GLASS"],
            dataset_class_names(detection, detection_config),
        )

    def test_external_mapping_requires_canonical_targets_and_reject_policy(self) -> None:
        valid = {
            "unmapped_class_policy": "reject",
            "mappings": {"scuff": "SCRATCH"},
        }
        self.assertEqual(
            {"scuff": "SCRATCH"},
            validate_class_remap_config(valid),
        )

        invalid = {
            "unmapped_class_policy": "guess",
            "mappings": {"scuff": "OTHER"},
        }
        with self.assertRaises(ValueError):
            validate_class_remap_config(invalid)

    def test_unknown_damage_label_is_not_guessed(self) -> None:
        self.assertEqual("PAINT_DAMAGE", canonicalize_damage_label("paint-damage"))
        with self.assertRaisesRegex(ValueError, "Unmapped"):
            canonicalize_damage_label("rust")

    def test_cardd_training_defaults_are_reproducible(self) -> None:
        args = build_detection_train_parser().parse_args([])

        self.assertEqual(100, args.epochs)
        self.assertEqual(8, args.batch)
        self.assertEqual(640, args.imgsz)
        self.assertEqual(20, args.patience)
        self.assertEqual(42, args.seed)
        self.assertEqual("auto", args.device)
        self.assertEqual("damage-detection-v2-cardd-5class-640", args.name)

    def test_validator_and_ultralytics_resolve_yaml_relative_splits_identically(
        self,
    ) -> None:
        workspace = AI_SERVICE_ROOT / "tests" / ".ultralytics-path-test"
        if workspace.exists():
            shutil.rmtree(workspace)
        try:
            for split in ("train", "val", "test"):
                (workspace / "images" / split / "cardd").mkdir(parents=True)
            config_path = workspace / "data.yaml"
            config_path.write_text(
                "train: images/train/cardd\n"
                "val: images/val/cardd\n"
                "test: images/test/cardd\n"
                "names:\n"
                "  0: SCRATCH\n"
                "  1: DENT\n",
                encoding="utf-8",
            )
            config = validate_dataset_config(config_path)

            from ultralytics.data.utils import check_det_dataset

            with patch("ultralytics.data.utils.check_font"):
                ultralytics_config = check_det_dataset(
                    str(config_path), autodownload=False
                )

            for split in ("train", "val", "test"):
                self.assertEqual(
                    resolve_split_path(config_path, config, split),
                    Path(ultralytics_config[split]),
                )
        finally:
            if workspace.exists():
                shutil.rmtree(workspace)

    def test_relative_explicit_dataset_root_is_rejected(self) -> None:
        config_path = AI_SERVICE_ROOT / "datasets" / "example" / "data.yaml"
        with self.assertRaisesRegex(ValueError, "Omit 'path'"):
            resolve_split_path(
                config_path,
                {"path": ".", "train": "images/train"},
                "train",
            )


class EvaluationOutputTest(unittest.TestCase):
    def test_metric_report_exposes_aggregate_and_per_class_values(self) -> None:
        metric = SimpleNamespace(
            mean_results=lambda: [0.7, 0.6, 0.65, 0.4],
            class_result=lambda index: [0.8 - index * 0.1, 0.5, 0.6, 0.35],
            ap_class_index=[0, 1],
        )
        report = metric_report(
            SimpleNamespace(box=metric),
            {0: "SCRATCH", 1: "DENT"},
        )

        self.assertEqual(0.65, report["map50"])
        self.assertEqual("DENT", report["per_class"][1]["class_name"])
        self.assertAlmostEqual(0.7, report["per_class"][1]["precision"])

    def test_metric_report_marks_class_without_ground_truth_as_unavailable(self) -> None:
        metric = SimpleNamespace(
            mean_results=lambda: [0.7, 0.6, 0.65, 0.4],
            class_result=lambda index: [0.8, 0.5, 0.6, 0.35],
            ap_class_index=[1],
        )
        report = metric_report(
            SimpleNamespace(box=metric),
            {0: "SCRATCH", 1: "DENT"},
        )

        self.assertIsNone(report["per_class"][0]["precision"])
        self.assertEqual(0.8, report["per_class"][1]["precision"])

    def test_model_taxonomy_mapping_finds_shared_classes(self) -> None:
        production = canonical_model_names({0: "Broken part", 1: "Dent", 2: "Scratch"})
        detection_v2 = canonical_model_names(
            {
                0: "SCRATCH",
                1: "DENT",
                2: "CRACK",
                3: "BROKEN_PART",
                4: "BROKEN_GLASS",
            }
        )

        self.assertEqual(
            ["SCRATCH", "DENT", "BROKEN_PART"],
            shared_model_classes([production, detection_v2]),
        )

    def test_dataset_labels_are_remapped_to_model_class_ids(self) -> None:
        text = remap_label_lines(
            [
                "0 0.5 0.5 0.2 0.2",
                "3 0.4 0.4 0.1 0.1",
                "4 0.3 0.3 0.1 0.1",
            ],
            ["SCRATCH", "DENT", "CRACK", "BROKEN_PART", "BROKEN_GLASS"],
            {"BROKEN_PART": 0, "DENT": 1, "SCRATCH": 2},
            {"SCRATCH", "DENT", "BROKEN_PART"},
        )

        self.assertEqual(
            "2 0.5 0.5 0.2 0.2\n0 0.4 0.4 0.1 0.1\n",
            text,
        )

    def test_review_flags_surface_false_positive_and_type_errors(self) -> None:
        prediction = {
            "predicted_damage": True,
            "predicted_types": "SCRATCH",
            "highest_confidence": 0.2,
        }
        clean_flags = review_flags(
            prediction,
            {"expected_damage": False, "expected_types": []},
            low_confidence=0.3,
        )
        self.assertIn("CLEAN_FALSE_POSITIVE", clean_flags)
        self.assertIn("LOW_CONFIDENCE_FALSE_POSITIVE", clean_flags)

        type_flags = review_flags(
            prediction,
            {"expected_damage": True, "expected_types": ["DENT"]},
            low_confidence=0.3,
        )
        self.assertIn("INCORRECT_DAMAGE_TYPE", type_flags)


if __name__ == "__main__":
    unittest.main()
