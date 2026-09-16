from io import BytesIO
from pathlib import Path
from typing import Any

from PIL import Image, UnidentifiedImageError
from ultralytics import YOLO

from app.schemas import (
    BoundingBox,
    DamageAnalysisResponse,
    DetectedObject,
    DamageRecommendation,
)


PROJECT_ROOT = Path(__file__).resolve().parent.parent

DEFAULT_VEHICLE_MODEL_PATH = (
        PROJECT_ROOT / "yolo11n.pt"
)

DEFAULT_DAMAGE_MODEL_PATH = (
        PROJECT_ROOT / "models" / "best.pt"
)

DEFAULT_VEHICLE_PART_MODEL_PATH = (
        PROJECT_ROOT
        / "models"
        / "vehicle_part_best.pt"
)


class DamageAnalyzer:
    """
    Araç, hasar ve araç parçası tespiti yapan analiz servisi.

    Genel YOLO modeli araç tespiti için,
    özel hasar modeli hasarlı bölgeleri tespit etmek için,
    araç parçası modeli ise hasarın bulunduğu parçayı
    belirlemek için kullanılır.
    """

    VEHICLE_LABELS = {
        "car",
        "truck",
        "bus",
        "motorcycle",
    }

    VEHICLE_PART_MAPPING = {
        "back-bumper": "REAR_BUMPER",
        "back-door": "REAR_DOOR",
        "back-wheel": "REAR_WHEEL",
        "back-window": "REAR_WINDOW",
        "back-windshield": "REAR_WINDSHIELD",
        "fender": "FENDER",
        "front-bumper": "FRONT_BUMPER",
        "front-door": "FRONT_DOOR",
        "front-wheel": "FRONT_WHEEL",
        "front-window": "FRONT_WINDOW",
        "grille": "GRILLE",
        "headlight": "HEADLIGHT",
        "hood": "HOOD",
        "license-plate": "LICENSE_PLATE",
        "mirror": "MIRROR",
        "quarter-panel": "QUARTER_PANEL",
        "rocker-panel": "ROCKER_PANEL",
        "roof": "ROOF",
        "tail-light": "TAIL_LIGHT",
        "trunk": "TRUNK",
        "windshield": "WINDSHIELD",
    }

    def __init__(
            self,
            vehicle_model_path: str | Path = (
                    DEFAULT_VEHICLE_MODEL_PATH
            ),
            damage_model_path: str | Path = (
                    DEFAULT_DAMAGE_MODEL_PATH
            ),
            vehicle_part_model_path: str | Path = (
                    DEFAULT_VEHICLE_PART_MODEL_PATH
            ),
            vehicle_confidence_threshold: float = 0.40,
            damage_confidence_threshold: float = 0.25,
            damage_iou_threshold: float = 0.45,
            vehicle_part_confidence_threshold: float = 0.25,
            minimum_part_overlap_ratio: float = 0.25,
            affected_part_damage_confidence_threshold: float = 0.50,
            damage_recommendation_confidence_threshold: float = 0.30,
    ) -> None:
        self.vehicle_model_path = Path(
            vehicle_model_path
        )

        self.damage_model_path = Path(
            damage_model_path
        )

        self.vehicle_part_model_path = Path(
            vehicle_part_model_path
        )

        self.vehicle_confidence_threshold = (
            vehicle_confidence_threshold
        )

        self.damage_confidence_threshold = (
            damage_confidence_threshold
        )

        self.damage_iou_threshold = (
            damage_iou_threshold
        )

        self.vehicle_part_confidence_threshold = (
            vehicle_part_confidence_threshold
        )

        self.minimum_part_overlap_ratio = (
            minimum_part_overlap_ratio
        )

        self.affected_part_damage_confidence_threshold = (
            affected_part_damage_confidence_threshold
        )

        self.damage_recommendation_confidence_threshold = (
            damage_recommendation_confidence_threshold
        )

        self._validate_model_paths()

        self.vehicle_model = YOLO(
            str(self.vehicle_model_path)
        )

        self.damage_model = YOLO(
            str(self.damage_model_path)
        )

        self.vehicle_part_model = YOLO(
            str(self.vehicle_part_model_path)
        )

    def analyze(
            self,
            file_content: bytes,
            filename: str,
    ) -> DamageAnalysisResponse:
        safe_filename = Path(
            filename or "vehicle.jpg"
        ).name.lower()

        image = self._load_image(
            file_content
        )

        vehicle_results = self.vehicle_model.predict(
            source=image,
            conf=self.vehicle_confidence_threshold,
            verbose=False,
        )

        vehicle_detections = self._extract_detections(
            vehicle_results
        )

        vehicle_detections = [
            detection
            for detection in vehicle_detections
            if detection.label.lower()
               in self.VEHICLE_LABELS
        ]

        if not vehicle_detections:
            raise ValueError(
                "Uploaded image does not contain a recognizable vehicle."
            )

        (
            analysis_image,
            crop_offset_x,
            crop_offset_y,
        ) = self._crop_primary_vehicle(
            image=image,
            vehicle_detections=vehicle_detections,
        )

        damage_results = self.damage_model.predict(
            source=analysis_image,
            conf=self.damage_confidence_threshold,
            iou=self.damage_iou_threshold,
            max_det=20,
            agnostic_nms=False,
            verbose=False,
        )

        vehicle_part_results = (
            self.vehicle_part_model.predict(
                source=analysis_image,
                conf=(
                    self.vehicle_part_confidence_threshold
                ),
                iou=0.50,
                max_det=50,
                verbose=False,
            )
        )

        damage_detections = (
            self._extract_detections(
                damage_results
            )
        )

        vehicle_part_detections = (
            self._extract_detections(
                vehicle_part_results
            )
        )

        damage_detections = (
            self._translate_detections(
                detections=damage_detections,
                offset_x=crop_offset_x,
                offset_y=crop_offset_y,
            )
        )

        vehicle_part_detections = (
            self._translate_detections(
                detections=vehicle_part_detections,
                offset_x=crop_offset_x,
                offset_y=crop_offset_y,
            )
        )

        if not damage_detections:
            return self._build_no_damage_response(
                filename=safe_filename
            )

        matched_damage_detections = (
            self._assign_parts_to_damage_detections(
                damage_detections=damage_detections,
                vehicle_part_detections=(
                    vehicle_part_detections
                ),
            )
        )

        primary_damage = max(
            matched_damage_detections,
            key=lambda detection: (
                detection.confidence
            ),
        )

        affected_parts = (
            self._extract_affected_parts(
                matched_damage_detections
            )
        )

        return self._build_damage_response(
            filename=safe_filename,
            primary_damage=primary_damage,
            damage_detections=(
                matched_damage_detections
            ),
            affected_parts=affected_parts,
        )

    def _extract_affected_parts(
            self,
            damage_detections: list[DetectedObject],
    ) -> list[str]:
        affected_parts: list[str] = []

        for detection in damage_detections:
            if (
                    detection.confidence
                    < self
                    .affected_part_damage_confidence_threshold
            ):
                continue

            affected_part = (
                detection.affectedPart
            )

            if affected_part == "UNKNOWN":
                continue

            if affected_part not in affected_parts:
                affected_parts.append(
                    affected_part
                )

        return affected_parts

    def _build_repair_recommendations(
            self,
            damage_detections: list[DetectedObject],
            trusted_affected_parts: list[str],
    ) -> list[DamageRecommendation]:
        grouped_parts: dict[
            str,
            list[str],
        ] = {}

        for detection in damage_detections:
            if (
                    detection.confidence
                    < self
                    .damage_recommendation_confidence_threshold
            ):
                continue

            damage_type = (
                self._normalize_enum_value(
                    detection.label
                )
            )

            if damage_type not in grouped_parts:
                grouped_parts[
                    damage_type
                ] = []

            affected_part = (
                detection.affectedPart
            )

            if (
                    affected_part != "UNKNOWN"
                    and affected_part
                    in trusted_affected_parts
                    and affected_part
                    not in grouped_parts[damage_type]
            ):
                grouped_parts[
                    damage_type
                ].append(
                    affected_part
                )

        recommendations: list[
            DamageRecommendation
        ] = []

        for (
                damage_type,
                affected_parts,
        ) in grouped_parts.items():
            recommendations.append(
                DamageRecommendation(
                    damageType=damage_type,
                    recommendedAction=(
                        self
                        ._determine_recommended_action(
                            damage_type
                        )
                    ),
                    partReplacementRequired=(
                        self
                        ._determine_replacement_requirement(
                            damage_type
                        )
                    ),
                    affectedParts=affected_parts,
                )
            )

        return recommendations

    @staticmethod
    def _determine_damage_severity(
            damage_type: str,
            affected_part_count: int,
            highest_confidence: float,
    ) -> str:
        if damage_type == "NO_VISIBLE_DAMAGE":
            return "NONE"

        if damage_type == "BROKEN_PART":
            if affected_part_count >= 2:
                return "SEVERE"

            return "MODERATE"

        if affected_part_count >= 3:
            return "SEVERE"

        if affected_part_count == 2:
            return "MODERATE"

        if highest_confidence >= 0.60:
            return "MODERATE"

        return "MINOR"

    def _validate_model_paths(
            self,
    ) -> None:
        model_paths = {
            "Vehicle detection": (
                self.vehicle_model_path
            ),
            "Damage detection": (
                self.damage_model_path
            ),
            "Vehicle part detection": (
                self.vehicle_part_model_path
            ),
        }

        for (
                model_name,
                model_path,
        ) in model_paths.items():
            if not model_path.is_file():
                raise FileNotFoundError(
                    f"{model_name} model was not found: "
                    f"{model_path}"
                )

    def _build_damage_response(
            self,
            filename: str,
            primary_damage: DetectedObject,
            damage_detections: list[DetectedObject],
            affected_parts: list[str],
    ) -> DamageAnalysisResponse:
        damage_type = (
            self._normalize_enum_value(
                primary_damage.label
            )
        )

        repair_recommendations = (
            self._build_repair_recommendations(
                damage_detections=damage_detections,
                trusted_affected_parts=affected_parts,
            )
        )

        if not repair_recommendations:
            repair_recommendations = [
                DamageRecommendation(
                    damageType=damage_type,
                    recommendedAction=(
                        self._determine_recommended_action(
                            damage_type
                        )
                    ),
                    partReplacementRequired=(
                        self._determine_replacement_requirement(
                            damage_type
                        )
                    ),
                    affectedParts=affected_parts,
                )
            ]

        damage_types = [
            recommendation.damageType
            for recommendation
            in repair_recommendations
        ]

        damage_severity = (
            self._determine_damage_severity(
                damage_type=damage_type,
                affected_part_count=(
                    len(affected_parts)
                ),
                highest_confidence=(
                    primary_damage.confidence
                ),
            )
        )

        damage_type_text = (
            ", ".join(damage_types)
            if damage_types
            else damage_type
        )

        affected_part_text = (
            ", ".join(affected_parts)
            if affected_parts
            else "UNKNOWN"
        )

        return DamageAnalysisResponse(
            damageTypes=damage_types,
            damageSeverity=damage_severity,
            affectedParts=affected_parts,
            repairRecommendations=(
                repair_recommendations
            ),
            confidenceScore=(
                primary_damage.confidence
            ),
            analysisMessage=(
                f"{filename} adlı görselde "
                f"{len(damage_detections)} hasarlı "
                f"bölge tespit edildi. "
                f"Hasar türleri: "
                f"{damage_type_text}. "
                f"Hasar seviyesi: "
                f"{damage_severity}. "
                f"En yüksek güven skoru: "
                f"{primary_damage.confidence:.2f}. "
                f"Etkilenen parçalar: "
                f"{affected_part_text}."
            ),
            detections=damage_detections,
        )

    def _build_no_damage_response(
            self,
            filename: str,
    ) -> DamageAnalysisResponse:
        return DamageAnalysisResponse(
            damageTypes=["NO_VISIBLE_DAMAGE"],
            damageSeverity="NONE",
            affectedParts=[],
            repairRecommendations=[
                DamageRecommendation(
                    damageType="NO_VISIBLE_DAMAGE",
                    recommendedAction="NO_ACTION",
                    partReplacementRequired=False,
                    affectedParts=[],
                )
            ],
            confidenceScore=0.0,
            analysisMessage=(
                f"{filename} adlı görselde görünür hasar "
                f"tespit edilmedi. Bu sonuç yalnızca görüntüdeki "
                f"görünür hasar analizidir; mekanik veya profesyonel "
                f"ekspertiz garantisi değildir."
            ),
            detections=[],
        )

    def _assign_parts_to_damage_detections(
            self,
            damage_detections: list[DetectedObject],
            vehicle_part_detections: list[DetectedObject],
    ) -> list[DetectedObject]:
        for damage_detection in damage_detections:
            damage_detection.affectedPart = (
                self._match_damage_to_vehicle_part(
                    damage=damage_detection,
                    vehicle_parts=(
                        vehicle_part_detections
                    ),
                )
            )

        return damage_detections

    def _match_damage_to_vehicle_part(
            self,
            damage: DetectedObject,
            vehicle_parts: list[DetectedObject],
    ) -> str:
        best_vehicle_part = "UNKNOWN"
        best_score = 0.0

        for vehicle_part in vehicle_parts:
            normalized_label = (
                vehicle_part.label
                .strip()
                .lower()
            )

            mapped_vehicle_part = (
                self.VEHICLE_PART_MAPPING.get(
                    normalized_label
                )
            )

            if mapped_vehicle_part is None:
                continue

            overlap_ratio = (
                self._calculate_damage_overlap_ratio(
                    damage.boundingBox,
                    vehicle_part.boundingBox,
                )
            )

            if (
                    overlap_ratio
                    < self.minimum_part_overlap_ratio
            ):
                continue

            score = (
                    overlap_ratio * 0.80
                    + vehicle_part.confidence * 0.20
            )

            if score > best_score:
                best_score = score
                best_vehicle_part = (
                    mapped_vehicle_part
                )

        return best_vehicle_part

    @staticmethod
    def _calculate_damage_overlap_ratio(
            damage_box: BoundingBox,
            part_box: BoundingBox,
    ) -> float:
        intersection_x1 = max(
            damage_box.x1,
            part_box.x1,
        )

        intersection_y1 = max(
            damage_box.y1,
            part_box.y1,
        )

        intersection_x2 = min(
            damage_box.x2,
            part_box.x2,
        )

        intersection_y2 = min(
            damage_box.y2,
            part_box.y2,
        )

        intersection_width = max(
            0.0,
            intersection_x2
            - intersection_x1,
            )

        intersection_height = max(
            0.0,
            intersection_y2
            - intersection_y1,
            )

        intersection_area = (
                intersection_width
                * intersection_height
        )

        damage_width = max(
            0.0,
            damage_box.x2
            - damage_box.x1,
            )

        damage_height = max(
            0.0,
            damage_box.y2
            - damage_box.y1,
            )

        damage_area = (
                damage_width
                * damage_height
        )

        if damage_area <= 0:
            return 0.0

        return (
                intersection_area
                / damage_area
        )

    @staticmethod
    def _normalize_enum_value(
            value: str,
    ) -> str:
        return (
            value.strip()
            .upper()
            .replace("-", "_")
            .replace(" ", "_")
        )

    @staticmethod
    def _determine_recommended_action(
            damage_type: str,
    ) -> str:
        recommendations = {
            "SCRATCH": "PAINT_TOUCH_UP",
            "DENT": "DENT_REPAIR",
            "CRACK": "PART_REPAIR",
            "PAINT_DAMAGE": "FULL_PAINTING",
            "BROKEN_PART": "PART_REPLACEMENT",
        }

        return recommendations.get(
            damage_type,
            "PART_REPAIR",
        )

    @staticmethod
    def _determine_replacement_requirement(
            damage_type: str,
    ) -> bool:
        return (
                damage_type == "BROKEN_PART"
        )

    @staticmethod
    def _load_image(
            file_content: bytes,
    ) -> Image.Image:
        if not file_content:
            raise ValueError(
                "Uploaded image is empty."
            )

        try:
            with Image.open(
                    BytesIO(file_content)
            ) as image:
                image.verify()

            with Image.open(
                    BytesIO(file_content)
            ) as verified_image:
                return (
                    verified_image
                    .convert("RGB")
                    .copy()
                )

        except (
                UnidentifiedImageError,
                OSError,
                ValueError,
        ) as exc:
            raise ValueError(
                "Uploaded file is not a valid image."
            ) from exc

    @staticmethod
    def _extract_detections(
            results: list[Any],
    ) -> list[DetectedObject]:
        detections: list[
            DetectedObject
        ] = []

        for result in results:
            if result.boxes is None:
                continue

            class_names = result.names

            for box in result.boxes:
                class_id = int(
                    box.cls[0].item()
                )

                confidence = round(
                    float(
                        box.conf[0].item()
                    ),
                    4,
                )

                coordinates = (
                    box.xyxy[0]
                    .cpu()
                    .tolist()
                )

                detections.append(
                    DetectedObject(
                        label=str(
                            class_names[
                                class_id
                            ]
                        ),
                        confidence=confidence,
                        affectedPart="UNKNOWN",
                        boundingBox=(
                            BoundingBox(
                                x1=round(
                                    coordinates[0],
                                    2,
                                ),
                                y1=round(
                                    coordinates[1],
                                    2,
                                ),
                                x2=round(
                                    coordinates[2],
                                    2,
                                ),
                                y2=round(
                                    coordinates[3],
                                    2,
                                ),
                            )
                        ),
                    )
                )

        return detections

    @staticmethod
    def _translate_detections(
            detections: list[DetectedObject],
            offset_x: int,
            offset_y: int,
    ) -> list[DetectedObject]:
        if (
                offset_x == 0
                and offset_y == 0
        ):
            return detections

        translated_detections: list[
            DetectedObject
        ] = []

        for detection in detections:
            box = detection.boundingBox

            translated_detections.append(
                DetectedObject(
                    label=detection.label,
                    confidence=(
                        detection.confidence
                    ),
                    affectedPart=(
                        detection.affectedPart
                    ),
                    boundingBox=BoundingBox(
                        x1=round(
                            box.x1 + offset_x,
                            2,
                            ),
                        y1=round(
                            box.y1 + offset_y,
                            2,
                            ),
                        x2=round(
                            box.x2 + offset_x,
                            2,
                            ),
                        y2=round(
                            box.y2 + offset_y,
                            2,
                            ),
                    ),
                )
            )

        return translated_detections

    @staticmethod
    def _crop_primary_vehicle(
            image: Image.Image,
            vehicle_detections: list[DetectedObject],
    ) -> tuple[
        Image.Image,
        int,
        int,
    ]:
        if not vehicle_detections:
            return image, 0, 0

        primary_vehicle = max(
            vehicle_detections,
            key=lambda detection: (
                    max(
                        0.0,
                        (
                                detection
                                .boundingBox.x2
                                - detection
                                .boundingBox.x1
                        ),
                    )
                    * max(
                0.0,
                (
                        detection
                        .boundingBox.y2
                        - detection
                        .boundingBox.y1
                ),
            )
            ),
        )

        box = (
            primary_vehicle.boundingBox
        )

        image_width, image_height = (
            image.size
        )

        box_width = max(
            0.0,
            box.x2 - box.x1,
            )

        box_height = max(
            0.0,
            box.y2 - box.y1,
            )

        if (
                box_width <= 0
                or box_height <= 0
        ):
            return image, 0, 0

        padding_x = int(
            box_width * 0.05
        )

        padding_y = int(
            box_height * 0.05
        )

        left = max(
            0,
            int(box.x1) - padding_x,
            )

        top = max(
            0,
            int(box.y1) - padding_y,
            )

        right = min(
            image_width,
            int(box.x2) + padding_x,
            )

        bottom = min(
            image_height,
            int(box.y2) + padding_y,
            )

        if (
                right <= left
                or bottom <= top
        ):
            return image, 0, 0

        cropped_image = image.crop(
            (
                left,
                top,
                right,
                bottom,
            )
        )

        return (
            cropped_image,
            left,
            top,
        )
