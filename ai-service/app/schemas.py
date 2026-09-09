from enum import Enum

from pydantic import BaseModel, Field


class DamageSeverity(str, Enum):
    UNKNOWN = "UNKNOWN"
    NONE = "NONE"
    MINOR = "MINOR"
    MODERATE = "MODERATE"
    SEVERE = "SEVERE"


class DamageType(str, Enum):
    NO_VISIBLE_DAMAGE = "NO_VISIBLE_DAMAGE"
    SCRATCH = "SCRATCH"
    PAINT_DAMAGE = "PAINT_DAMAGE"
    DENT = "DENT"
    CRACK = "CRACK"
    BROKEN_PART = "BROKEN_PART"
    BROKEN_GLASS = "BROKEN_GLASS"
    DEFORMATION = "DEFORMATION"


class RepairAction(str, Enum):
    NO_ACTION = "NO_ACTION"
    POLISHING = "POLISHING"
    PAINT_TOUCH_UP = "PAINT_TOUCH_UP"
    FULL_PAINTING = "FULL_PAINTING"
    PAINTLESS_DENT_REPAIR = "PAINTLESS_DENT_REPAIR"
    DENT_REPAIR = "DENT_REPAIR"
    PLASTIC_REPAIR = "PLASTIC_REPAIR"
    PART_REPAIR = "PART_REPAIR"
    PART_REPLACEMENT = "PART_REPLACEMENT"
    GLASS_REPAIR = "GLASS_REPAIR"
    GLASS_REPLACEMENT = "GLASS_REPLACEMENT"
    HEADLIGHT_REPAIR = "HEADLIGHT_REPAIR"
    HEADLIGHT_REPLACEMENT = "HEADLIGHT_REPLACEMENT"


class VehiclePart(str, Enum):
    UNKNOWN = "UNKNOWN"

    FRONT_BUMPER = "FRONT_BUMPER"
    REAR_BUMPER = "REAR_BUMPER"

    FRONT_DOOR = "FRONT_DOOR"
    REAR_DOOR = "REAR_DOOR"

    FRONT_WHEEL = "FRONT_WHEEL"
    REAR_WHEEL = "REAR_WHEEL"

    FRONT_WINDOW = "FRONT_WINDOW"
    REAR_WINDOW = "REAR_WINDOW"

    WINDSHIELD = "WINDSHIELD"
    REAR_WINDSHIELD = "REAR_WINDSHIELD"

    FENDER = "FENDER"
    QUARTER_PANEL = "QUARTER_PANEL"
    ROCKER_PANEL = "ROCKER_PANEL"

    GRILLE = "GRILLE"
    HEADLIGHT = "HEADLIGHT"
    TAIL_LIGHT = "TAIL_LIGHT"

    HOOD = "HOOD"
    LICENSE_PLATE = "LICENSE_PLATE"
    MIRROR = "MIRROR"
    ROOF = "ROOF"
    TRUNK = "TRUNK"


class BoundingBox(BaseModel):
    x1: float
    y1: float
    x2: float
    y2: float


class DetectedObject(BaseModel):
    label: str

    confidence: float = Field(
        ge=0.0,
        le=1.0,
    )

    affectedPart: VehiclePart = VehiclePart.UNKNOWN

    boundingBox: BoundingBox


class DamageRecommendation(BaseModel):
    damageType: DamageType

    recommendedAction: RepairAction

    partReplacementRequired: bool

    affectedParts: list[VehiclePart] = Field(
        default_factory=list
    )


class DamageAnalysisResponse(BaseModel):
    damageSeverity: DamageSeverity

    affectedParts: list[VehiclePart] = Field(
        default_factory=list
    )

    damageTypes: list[DamageType] = Field(
        default_factory=list
    )

    repairRecommendations: list[
        DamageRecommendation
    ] = Field(
        default_factory=list
    )

    confidenceScore: float = Field(
        ge=0.0,
        le=1.0,
    )

    analysisMessage: str

    detections: list[DetectedObject] = Field(
        default_factory=list
    )