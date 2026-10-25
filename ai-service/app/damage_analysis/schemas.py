from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, model_validator

Damage = Literal['SCRATCH', 'PAINT_DAMAGE', 'DENT', 'CRACK', 'BROKEN_PART',
                 'BROKEN_GLASS', 'DEFORMATION', 'CORROSION', 'CRACKED',
                 'FLAKING', 'MISSING_PART', 'PAINT_CHIP']
Part = Literal['UNKNOWN', 'FRONT_BUMPER', 'REAR_BUMPER', 'FRONT_DOOR', 'REAR_DOOR',
               'FRONT_WHEEL', 'REAR_WHEEL', 'FRONT_WINDOW', 'REAR_WINDOW',
               'WINDSHIELD', 'REAR_WINDSHIELD', 'FENDER', 'QUARTER_PANEL',
               'ROCKER_PANEL', 'GRILLE', 'HEADLIGHT', 'TAIL_LIGHT', 'HOOD',
               'LICENSE_PLATE', 'MIRROR', 'ROOF', 'TRUNK']
Severity = Literal['MINOR', 'MODERATE', 'SEVERE', 'UNKNOWN']
Action = Literal['POLISHING', 'PAINT_TOUCH_UP', 'FULL_PAINTING', 'PAINTLESS_DENT_REPAIR',
                 'DENT_REPAIR', 'PLASTIC_REPAIR', 'PART_REPAIR', 'PART_REPLACEMENT',
                 'GLASS_REPAIR', 'GLASS_REPLACEMENT', 'HEADLIGHT_REPAIR',
                 'HEADLIGHT_REPLACEMENT', 'PROFESSIONAL_INSPECTION']


class StrictModel(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True, str_strip_whitespace=True)


class VisualFinding(StrictModel):
    damageType: Damage
    affectedPart: Part
    severity: Severity
    description: str = Field(min_length=10, max_length=400)
    recommendedAction: Action
    repairNotes: str = Field(min_length=10, max_length=300)
    replacementAssessment: Literal['POSSIBLE', 'NOT_INDICATED', 'UNDETERMINED']
    evidenceImages: list[Literal['OVERVIEW', 'DETAIL']] = Field(min_length=1, max_length=2)


class PhotoAssessment(StrictModel):
    overviewUsable: bool
    detailUsable: bool
    sameVehicleAndArea: bool


class GeminiAnalysis(StrictModel):
    analysisOutcome: Literal['DAMAGE_DETECTED', 'NEEDS_MORE_PHOTOS', 'INCONCLUSIVE']
    damageSeverity: Severity
    photoAssessment: PhotoAssessment
    visualFindings: list[VisualFinding] = Field(max_length=8)
    analysisMessage: str = Field(min_length=10, max_length=500)
    additionalPhotoGuidance: str = Field(max_length=400)

    @model_validator(mode='after')
    def consistent_evidence(self):
        adequate = all((self.photoAssessment.overviewUsable, self.photoAssessment.detailUsable,
                        self.photoAssessment.sameVehicleAndArea))
        if self.analysisOutcome == 'DAMAGE_DETECTED':
            if not adequate or not self.visualFindings or self.additionalPhotoGuidance:
                raise ValueError('Successful analysis requires two matching usable photos and findings')
            severities = [f.severity for f in self.visualFindings]
            expected = 'UNKNOWN' if 'UNKNOWN' in severities else max(severities, key=['MINOR', 'MODERATE', 'SEVERE'].index)
            if self.damageSeverity != expected:
                raise ValueError('Overall severity must preserve uncertainty and match the visible findings')
        elif self.visualFindings or self.damageSeverity != 'UNKNOWN' or not self.additionalPhotoGuidance.strip():
            raise ValueError('An inconclusive analysis must remain unknown and request better evidence')
        if len({(f.damageType, f.affectedPart) for f in self.visualFindings}) != len(self.visualFindings):
            raise ValueError('Duplicate findings are not allowed')
        for finding in self.visualFindings:
            if len(set(finding.evidenceImages)) != len(finding.evidenceImages):
                raise ValueError('Duplicate evidence roles')
        return self


class Recommendation(StrictModel):
    damageType: Damage
    recommendedAction: Action
    partReplacementRequired: None = None
    affectedParts: list[Part]


class AnalysisResponse(GeminiAnalysis):
    analysisMessage: str = Field(min_length=10, max_length=1000)
    schemaVersion: Literal['gemini-vision-v1'] = 'gemini-vision-v1'
    modelVersion: str
    confidenceScore: None = None
    detections: list = Field(default_factory=list, max_length=0)
    partDetections: list = Field(default_factory=list, max_length=0)
    damageTypes: list[Damage]
    affectedParts: list[Part]
    repairRecommendations: list[Recommendation]
