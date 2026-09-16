import unittest
from io import BytesIO
from unittest.mock import Mock

from PIL import Image
from app.damage_analyzer import DamageAnalyzer
from app.schemas import BoundingBox, DetectedObject


class DamageAnalyzerResultTest(unittest.TestCase):
    def setUp(self) -> None:
        self.analyzer = DamageAnalyzer.__new__(DamageAnalyzer)
        self.analyzer.damage_recommendation_confidence_threshold = 0.30

    def test_no_damage_response_uses_canonical_domain_values(self) -> None:
        result = self.analyzer._build_no_damage_response("vehicle.jpg")

        self.assertEqual("NONE", result.damageSeverity.value)
        self.assertEqual(["NO_VISIBLE_DAMAGE"], [item.value for item in result.damageTypes])
        self.assertEqual(1, len(result.repairRecommendations))
        self.assertEqual(
            "NO_ACTION",
            result.repairRecommendations[0].recommendedAction.value,
        )
        self.assertIn("profesyonel ekspertiz garantisi değildir", result.analysisMessage)

    def test_accepted_low_confidence_damage_remains_minor(self) -> None:
        detection = DetectedObject(
            label="scratch",
            confidence=0.28,
            affectedPart="FRONT_BUMPER",
            boundingBox=BoundingBox(x1=1, y1=1, x2=10, y2=10),
        )

        result = self.analyzer._build_damage_response(
            filename="vehicle.jpg",
            primary_damage=detection,
            damage_detections=[detection],
            affected_parts=["FRONT_BUMPER"],
        )

        self.assertEqual("MINOR", result.damageSeverity.value)
        self.assertEqual(["SCRATCH"], [item.value for item in result.damageTypes])
        self.assertEqual(
            "PAINT_TOUCH_UP",
            result.repairRecommendations[0].recommendedAction.value,
        )

    def test_image_without_a_recognizable_vehicle_is_rejected(self) -> None:
        image_bytes = BytesIO()
        Image.new("RGB", (4, 4), "white").save(image_bytes, format="JPEG")
        self.analyzer.vehicle_model = Mock()
        self.analyzer.vehicle_model.predict.return_value = []
        self.analyzer.vehicle_confidence_threshold = 0.40

        with self.assertRaisesRegex(ValueError, "recognizable vehicle"):
            self.analyzer.analyze(image_bytes.getvalue(), "empty-road.jpg")


if __name__ == "__main__":
    unittest.main()
