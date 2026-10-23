from io import BytesIO
from pathlib import Path
import logging
import re
from typing import Any

from PIL import ImageOps, Image, JpegImagePlugin, PngImagePlugin, WebPImagePlugin, UnidentifiedImageError
import cv2
import numpy as np
from ultralytics import YOLO

from app.model_contract import DAMAGE_CLASSES, PART_CLASSES, verify_artifact, verify_names

logger = logging.getLogger("uvicorn.error")


from app.schemas import (
    BoundingBox,
    DamageAnalysisResponse,
    DamageType,
    DetectedObject,
    DamageRecommendation,
    ImageQualityResponse,
    VehiclePart,
)


PROJECT_ROOT = Path(__file__).resolve().parent.parent

DEFAULT_VEHICLE_MODEL_PATH = (
        PROJECT_ROOT / "yolo11n.pt"
)

DEFAULT_DAMAGE_MODEL_PATH = (
        PROJECT_ROOT
        / "models"
        / "candidates"
        / "damage_detection_v2_cardd_5class.pt"
)

SUPPORTED_DAMAGE_MODEL_CLASSES = frozenset({
    "SCRATCH",
    "DENT",
    "CRACK",
    "BROKEN_PART",
    "BROKEN_GLASS",
})

APPLICATION_DAMAGE_TYPES = frozenset(
    damage_type.value
    for damage_type in DamageType
    if damage_type is not DamageType.NO_VISIBLE_DAMAGE
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

    VEHICLE_LABELS = {"car"}
    UNSUPPORTED_VEHICLE_LABELS = {"truck", "bus", "motorcycle", "bicycle", "train", "boat"}
    # Policy thresholds, not calibrated probabilities of being an automobile.
    PART_EVIDENCE_CONFIDENCE = 0.50
    PART_MATCH_MARGIN = 0.10
    PARTIAL_CAR_CONFIDENCE = 0.20
    BODY_PARTS = {
        "front-bumper", "back-bumper", "front-door", "back-door", "hood",
        "fender", "quarter-panel", "rocker-panel", "roof", "trunk",
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
            minimum_brightness: float = 35.0,
            minimum_blur_score: float = 20.0,
            minimum_vehicle_area_ratio: float = 0.12,
    ) -> None:
        self.vehicle_model_path = Path(
            vehicle_model_path
        )

        self.damage_model_path = DEFAULT_DAMAGE_MODEL_PATH

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

        self.minimum_brightness = minimum_brightness
        self.minimum_blur_score = minimum_blur_score
        self.minimum_vehicle_area_ratio = minimum_vehicle_area_ratio

        self._validate_model_paths()

        for path, role in ((self.vehicle_model_path, "vehicle"),
                           (self.damage_model_path, "damage"),
                           (self.vehicle_part_model_path, "part")):
            verify_artifact(path, role)

        self.vehicle_model = YOLO(
            str(self.vehicle_model_path)
        )

        self.damage_model = YOLO(
            str(self.damage_model_path)
        )

        verify_names(self.damage_model.names, DAMAGE_CLASSES)
        self.damage_class_mapping = (
            self._build_damage_class_mapping(
                self.damage_model.names
            )
        )

        self.vehicle_part_model = YOLO(
            str(self.vehicle_part_model_path)
        )
        verify_names(self.vehicle_part_model.names, PART_CLASSES)

    def validate_image_quality(
            self,
            file_content: bytes,
            purpose: str = "context",
    ) -> ImageQualityResponse:
        normalized_purpose = purpose.strip().lower()
        if normalized_purpose not in {"damage", "context"}:
            raise ValueError(
                "Image validation purpose must be 'damage' or 'context'."
            )
        image = self._load_image(file_content)
        quality_issue = self._photometric_quality_issue(image)
        if quality_issue is not None:
            return quality_issue

        issue, _, _ = self._automobile_evidence(
            image, allow_partial=normalized_purpose == "damage"
        )
        return issue or ImageQualityResponse(
            suitable=True, code="SUITABLE",
            message="Otomobil fotoğrafı görünür hasar analizi için uygun.",
        )

    def _automobile_evidence(self, image: Image.Image, allow_partial: bool = True):
        results = self.vehicle_model.predict(
            source=image, conf=self.PARTIAL_CAR_CONFIDENCE, verbose=False,
        )
        objects = self._extract_detections(results)
        def issue(code, message):
            return ImageQualityResponse(suitable=False, code=code, message=message), [], None

        # Mixed vehicles are ambiguous too: do not silently choose the largest.
        if any(d.label.lower() in self.UNSUPPORTED_VEHICLE_LABELS for d in objects):
            return issue("UNSUPPORTED_VEHICLE",
                         "Yalnızca otomobiller desteklenir. Diğer araçları içermeyen bir otomobil fotoğrafı çekin.")
        cars = [d for d in objects if d.label.lower() == "car"]
        if len(cars) > 1:
            return issue("MULTIPLE_VEHICLES", "Fotoğrafta tek bir otomobil bulunmalı.")
        if not cars:
            return issue("NO_VEHICLE",
                         "Otomobil olduğu doğrulanamıyor. Hasarı ve çevresindeki parçayı daha geniş açıyla çekin.")
        car = cars[0]
        if self._detection_area(car) / max(1, image.width * image.height) < self.minimum_vehicle_area_ratio:
            return issue("VEHICLE_TOO_SMALL", "Otomobil fotoğrafta çok küçük. Otomobile biraz daha yaklaşın.")
        if car.confidence >= self.vehicle_confidence_threshold:
            return None, cars, None
        if allow_partial:
            parts = self._detect_vehicle_parts(image)
            evidence_labels = {
                p.label.lower() for p in parts
                if p.label.lower() in self.VEHICLE_PART_MAPPING
                and p.confidence >= self.PART_EVIDENCE_CONFIDENCE
                and self._calculate_damage_overlap_ratio(p.boundingBox, car.boundingBox) >= 0.5
            }
            if len(evidence_labels) >= 2 and evidence_labels & self.BODY_PARTS:
                return None, [], parts
        return issue("UNCERTAIN_VEHICLE",
                     "Otomobil kanıtı yetersiz. Hasarla birlikte otomobilin daha geniş bir bölümünü çekin.")

    @staticmethod
    def _detection_area(detection: DetectedObject) -> float:
        box = detection.boundingBox
        return max(0.0, box.x2 - box.x1) * max(0.0, box.y2 - box.y1)

    def _photometric_quality_issue(self, image: Image.Image) -> ImageQualityResponse | None:
        grayscale = cv2.cvtColor(np.asarray(image), cv2.COLOR_RGB2GRAY)
        if float(grayscale.mean()) < self.minimum_brightness:
            return ImageQualityResponse(
                suitable=False,
                code="TOO_DARK",
                message="Fotoğraf çok karanlık. Daha aydınlık bir ortamda tekrar çekin.",
            )
        if self._blur_score(grayscale) < self.minimum_blur_score:
            return ImageQualityResponse(
                suitable=False,
                code="TOO_BLURRY",
                message="Görüntü yeterince net değil. Kamerayı sabit tutup tekrar çekin.",
            )
        return None

    @staticmethod
    def _blur_score(grayscale: np.ndarray) -> float:
        laplacian = cv2.Laplacian(grayscale, cv2.CV_64F)
        # Same float64 population variance as NumPy .var(), reusing this
        # disposable buffer instead of allocating another full-size array.
        laplacian -= laplacian.mean()
        np.square(laplacian, out=laplacian)
        return float(laplacian.mean())

    def _detect_vehicle_parts(self, image: Image.Image) -> list[DetectedObject]:
        results = self.vehicle_part_model.predict(
            source=image,
            conf=self.vehicle_part_confidence_threshold,
            iou=0.50,
            max_det=50,
            verbose=False,
        )
        return self._extract_detections(results)

    def analyze(
            self,
            file_content: bytes,
            filename: str,
            vehicle_region: str | None = None,
    ) -> DamageAnalysisResponse:
        if vehicle_region not in {None, "FRONT", "REAR"}:
            raise ValueError("vehicle_region must be FRONT or REAR.")
        safe_filename = Path(
            filename or "vehicle.jpg"
        ).name.lower()

        image = self._load_image(
            file_content
        )
        quality_issue = self._photometric_quality_issue(image)
        if quality_issue is not None:
            raise ValueError(quality_issue.message)

        scope_issue, vehicle_detections, vehicle_part_detections = self._automobile_evidence(image)
        if scope_issue is not None:
            raise ValueError(scope_issue.message)

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

        damage_detections = (
            self._extract_detections(
                damage_results,
                class_name_mapping=(
                    self.damage_class_mapping
                ),
            )
        )

        if not damage_detections:
            return self._build_no_damage_response(
                filename=safe_filename
            )


        # Weak detections are inconclusive, not a clean bill of health.
        damage_detections = [
            d for d in damage_detections
            if d.confidence >= self.damage_recommendation_confidence_threshold
        ]
        if not damage_detections:
            raise ValueError("Görünür hasar güvenilir şekilde değerlendirilemedi. Daha net bir fotoğraf çekin.")

        if vehicle_part_detections is None:
            vehicle_part_detections = self._detect_vehicle_parts(analysis_image)


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


        matched_damage_detections = (
            self._assign_parts_to_damage_detections(
                damage_detections=damage_detections,
                vehicle_part_detections=(
                    vehicle_part_detections
                ),
            )
        )
        self._apply_vehicle_region_constraint(matched_damage_detections, vehicle_region)

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

    def analyze_pair(
            self,
            damage_file_content: bytes,
            context_file_content: bytes,
            filename: str,
            vehicle_region: str | None = None,
    ) -> DamageAnalysisResponse:
        # A class name is not cross-image correspondence. Preserve the legacy
        # API, but require independent evidence and never copy parts across photos.
        context = self.validate_image_quality(context_file_content, purpose="context")
        if not context.suitable:
            raise ValueError(context.message)
        return self.analyze(damage_file_content, filename, vehicle_region)

    @staticmethod
    def _apply_vehicle_region_constraint(
            damage_detections: list[DetectedObject],
            vehicle_region: str | None,
    ) -> None:
        if vehicle_region not in {"FRONT", "REAR"}:
            return

        paired_parts = {
            "FRONT_BUMPER": ("FRONT_BUMPER", "REAR_BUMPER"),
            "REAR_BUMPER": ("FRONT_BUMPER", "REAR_BUMPER"),
            "FRONT_DOOR": ("FRONT_DOOR", "REAR_DOOR"),
            "REAR_DOOR": ("FRONT_DOOR", "REAR_DOOR"),
            "FRONT_WHEEL": ("FRONT_WHEEL", "REAR_WHEEL"),
            "REAR_WHEEL": ("FRONT_WHEEL", "REAR_WHEEL"),
            "FRONT_WINDOW": ("FRONT_WINDOW", "REAR_WINDOW"),
            "REAR_WINDOW": ("FRONT_WINDOW", "REAR_WINDOW"),
        }

        for detection in damage_detections:
            part_value = (
                detection.affectedPart.value
                if hasattr(detection.affectedPart, "value")
                else str(detection.affectedPart)
            )
            pair = paired_parts.get(part_value)
            if pair is None:
                continue

            corrected_part = pair[0] if vehicle_region == "FRONT" else pair[1]
            detection.affectedPart = (
                VehiclePart(part_value) if part_value == corrected_part else VehiclePart.UNKNOWN
            )
            logger.info(
                "Vehicle region constraint: region=%s original=%s corrected=%s",
                vehicle_region,
                part_value,
                detection.affectedPart.value,
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
    ) -> str:
        if damage_type == "NO_VISIBLE_DAMAGE":
            return "NONE"

        # The checkpoint has no severity labels. Part count is not severity.
        return "UNKNOWN"

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
            raise ValueError("Görünür hasar güvenilir şekilde değerlendirilemedi. Daha net bir fotoğraf çekin.")

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
            )
        )

        damage_type_text = (
            ", ".join("Lamba kırığı belirtisi" if t == "BROKEN_PART" else t for t in damage_types)
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
                f"Görüntüde {len(damage_detections)} olası hasar bölgesi: {damage_type_text}. "
                f"Etkilenen parçalar: {affected_part_text}. "
                "Hasar şiddeti, onarım yöntemi ve parça değişimi fotoğraftan belirlenemedi; "
                "fiziksel inceleme gerekir. Onarım gereksiz olduğu sonucu çıkarılamaz. "
                "Model skoru doğruluk yüzdesi değildir."
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
            damage_detection.affectedPart = VehiclePart(
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
        candidates: dict[str, float] = {}
        allowed_parts = {
            "BROKEN_PART": {"HEADLIGHT", "TAIL_LIGHT"},
            "BROKEN_GLASS": {"WINDSHIELD", "REAR_WINDSHIELD", "FRONT_WINDOW", "REAR_WINDOW"},
            "DENT": {"FRONT_BUMPER", "REAR_BUMPER", "FRONT_DOOR", "REAR_DOOR",
                     "FENDER", "QUARTER_PANEL", "ROCKER_PANEL", "HOOD", "ROOF", "TRUNK"},
        }.get(damage.label.upper())
        for part in vehicle_parts:
            mapped = self.VEHICLE_PART_MAPPING.get(part.label.strip().lower())
            if mapped is None or part.confidence < self.PART_EVIDENCE_CONFIDENCE:
                continue
            if allowed_parts is not None and mapped not in allowed_parts:
                continue
            overlap = self._calculate_damage_overlap_ratio(damage.boundingBox, part.boundingBox)
            if overlap < max(self.minimum_part_overlap_ratio, 0.50):
                continue
            score = overlap * .80 + part.confidence * .20
            candidates[mapped] = max(score, candidates.get(mapped, 0.0))
        ranked = sorted(candidates.items(), key=lambda item: item[1], reverse=True)
        if not ranked or (len(ranked) > 1 and ranked[0][1] - ranked[1][1] < self.PART_MATCH_MARGIN):
            return "UNKNOWN"
        return ranked[0][0]

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
        # No repair-action or replace/repair supervision exists in the model.
        return "NO_ACTION"

    @staticmethod
    def _determine_replacement_requirement(damage_type: str) -> bool:
        return False

    @classmethod
    def _build_damage_class_mapping(
            cls,
            model_class_names: Any,
    ) -> dict[int, str]:
        if isinstance(model_class_names, dict):
            class_items = list(model_class_names.items())
        elif isinstance(model_class_names, (list, tuple)):
            class_items = list(enumerate(model_class_names))
        else:
            raise ValueError(
                "Damage model class names must be a dictionary or list."
            )

        if not class_items:
            raise ValueError("Damage model does not expose any class names.")

        class_ids = [class_id for class_id, _ in class_items]
        if (
                any(
                    isinstance(class_id, bool)
                    or not isinstance(class_id, int)
                    for class_id in class_ids
                )
                or sorted(class_ids) != list(range(len(class_items)))
        ):
            raise ValueError(
                "Damage model class IDs must be contiguous integers starting at 0."
            )

        class_mapping: dict[int, str] = {}
        seen_damage_types: set[str] = set()

        for class_id, raw_name in sorted(class_items):
            if (
                    not isinstance(raw_name, str)
                    or not raw_name.strip()
                    or re.fullmatch(
                        r"[A-Za-z][A-Za-z0-9 _-]*",
                        raw_name.strip(),
                    ) is None
            ):
                raise ValueError(
                    f"Damage model class {class_id} has a malformed name: "
                    f"{raw_name!r}."
                )

            damage_type = cls._normalize_enum_value(raw_name)

            if damage_type in seen_damage_types:
                raise ValueError(
                    f"Damage model exposes duplicate class name: {damage_type}."
                )

            if damage_type not in APPLICATION_DAMAGE_TYPES:
                raise ValueError(
                    f"Damage model exposes unknown class name: {damage_type}."
                )

            if damage_type not in SUPPORTED_DAMAGE_MODEL_CLASSES:
                raise ValueError(
                    f"Damage model class is not supported by the active "
                    f"detector contract: {damage_type}."
                )

            seen_damage_types.add(damage_type)
            class_mapping[class_id] = damage_type

        return class_mapping

    @staticmethod
    def _load_image(
            file_content: bytes,
    ) -> Image.Image:
        if not file_content:
            raise ValueError(
                "Uploaded image is empty."
            )

        # Use the same Pillow codecs directly. Ultralytics replaces Image.open
        # with a HEIF fallback that may try to install a plugin for corrupt input;
        # this API only accepts JPEG/PNG/WEBP and must never install at request time.
        if file_content.startswith(b"\xff\xd8"):
            decoder = JpegImagePlugin.jpeg_factory
        elif file_content.startswith(b"\x89PNG\r\n\x1a\n"):
            decoder = PngImagePlugin.PngImageFile
        elif file_content[:4] == b"RIFF" and file_content[8:12] == b"WEBP":
            decoder = WebPImagePlugin.WebPImageFile
        else:
            raise ValueError("Uploaded file is not a valid JPG, PNG or WEBP image.")

        try:
            with decoder(
                    BytesIO(file_content)
            ) as image:
                # Compressed byte limits do not bound decoded buffers. Preserve
                # common 12/48/64 MP photos but reject extreme dimensions before
                # verify(), RGB conversion, OpenCV or model allocation.
                if image.width * image.height > 64_000_000:
                    raise ValueError("Image resolution exceeds the 64 megapixel limit.")
                # Image.open normally applies Pillow's existing pixel safety
                # policy; direct codecs must retain it before verify/convert.
                Image._decompression_bomb_check(image.size)
                image.verify()

            with decoder(
                    BytesIO(file_content)
            ) as verified_image:
                # convert() already owns a new RGB buffer; avoid duplicating it.
                ImageOps.exif_transpose(verified_image, in_place=True)
                return verified_image.convert("RGB")

        except (
                UnidentifiedImageError,
                OSError,
                ValueError,
                SyntaxError,
                EOFError,
                Image.DecompressionBombError,
        ) as exc:
            raise ValueError(
                "Uploaded file is not a valid image."
            ) from exc

    @staticmethod
    def _extract_detections(
            results: list[Any],
            class_name_mapping: dict[int, str] | None = None,
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

                if class_name_mapping is not None:
                    if class_id not in class_name_mapping:
                        raise ValueError(
                            "Damage model returned an unmapped class ID: "
                            f"{class_id}."
                        )

                    label = class_name_mapping[class_id]
                else:
                    label = str(class_names[class_id])

                detections.append(
                    DetectedObject(
                        label=label,
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
