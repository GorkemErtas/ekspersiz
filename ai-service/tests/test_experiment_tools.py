import unittest
from types import SimpleNamespace

import numpy as np

from experiments.config import (
    AI_SERVICE_ROOT,
    canonical_damage_classes,
    canonicalize_damage_label,
    dataset_class_names,
    validate_class_remap_config,
    validate_dataset_config,
)
from experiments.mask_metrics import (
    damage_part_intersection_ratio,
    damage_to_part_area_ratio,
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

        segmentation_config = (
            AI_SERVICE_ROOT / "datasets" / "vehicle_damage_segmentation_v1" / "data.yaml"
        )
        segmentation = validate_dataset_config(segmentation_config)
        self.assertEqual(
            expected,
            dataset_class_names(segmentation, segmentation_config),
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


class MaskMetricTest(unittest.TestCase):
    def test_mask_intersection_and_part_area_signals(self) -> None:
        damage = np.array([[1, 1], [0, 0]], dtype=np.uint8)
        part = np.array([[1, 0], [1, 1]], dtype=np.uint8)

        self.assertEqual(0.5, damage_part_intersection_ratio(damage, part))
        self.assertAlmostEqual(1 / 3, damage_to_part_area_ratio(damage, part))

    def test_mask_shapes_must_match(self) -> None:
        with self.assertRaisesRegex(ValueError, "same shape"):
            damage_part_intersection_ratio(np.ones((2, 2)), np.ones((3, 3)))


class EvaluationOutputTest(unittest.TestCase):
    def test_metric_report_exposes_aggregate_and_per_class_values(self) -> None:
        metric = SimpleNamespace(
            mean_results=lambda: [0.7, 0.6, 0.65, 0.4],
            class_result=lambda index: [0.8 - index * 0.1, 0.5, 0.6, 0.35],
            ap_class_index=[0, 1],
        )
        report = metric_report(
            SimpleNamespace(box=metric),
            "detect",
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
            "detect",
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
