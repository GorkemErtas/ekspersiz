from typing import Literal
from pydantic import BaseModel, Field, FiniteFloat


class Box(BaseModel):
    x1: FiniteFloat
    y1: FiniteFloat
    x2: FiniteFloat
    y2: FiniteFloat


class Detection(BaseModel):
    classId: int = Field(gt=0)
    code: str
    label: str
    task: Literal['damage','part']
    confidence: FiniteFloat = Field(ge=0,le=1)
    boundingBox: Box
    affectedPart: str = 'UNKNOWN'


class Recommendation(BaseModel):
    damageType: str
    recommendedAction: Literal['PROFESSIONAL_INSPECTION']
    partReplacementRequired: None = None
    affectedParts: list[str]


class UnifiedAnalysisResponse(BaseModel):
    schemaVersion: Literal['hitl-v1']
    modelVersion: str
    analysisOutcome: Literal['DAMAGE_DETECTED','INCONCLUSIVE']
    imageWidth: int = Field(gt=0)
    imageHeight: int = Field(gt=0)
    damageSeverity: Literal['UNKNOWN']
    confidenceScore: FiniteFloat | None = Field(default=None,ge=0,le=1)
    damageTypes: list[str]
    affectedParts: list[str]
    detections: list[Detection]
    partDetections: list[Detection]
    repairRecommendations: list[Recommendation]
    analysisMessage: str
