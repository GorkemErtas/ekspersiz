from dataclasses import dataclass
from .schemas import RetrievedChunk


@dataclass(frozen=True)
class VehicleSpecIdentity:
    year: int | None = None
    model: str | None = None
    trim: str | None = None
    market: str | None = None


@dataclass(frozen=True)
class SpecEvidenceResult:
    sufficient: bool
    score: float
    reason: str


def validate_vehicle_spec_evidence(identity: VehicleSpecIdentity,
                                   chunks: list[RetrievedChunk],
                                   min_similarity: float) -> SpecEvidenceResult:
    if identity.year is None or not identity.model:
        return SpecEvidenceResult(False, 0.0, "vehicle year and model are required")

    normalized_model = identity.model.casefold().strip()
    normalized_trim = identity.trim.casefold().strip() if identity.trim else None
    normalized_market = identity.market.upper().strip() if identity.market else None

    matching: list[RetrievedChunk] = []
    for chunk in chunks:
        if chunk.authority not in {"OFFICIAL", "VERIFIED"}:
            continue
        metadata = chunk.metadata or {}
        years = metadata.get("vehicle_years", [])
        models = [str(x).casefold().strip() for x in metadata.get("vehicle_models", [])]
        trims = [str(x).casefold().strip() for x in metadata.get("vehicle_trims", [])]
        market = (chunk.market or metadata.get("market") or "").upper().strip()

        if identity.year not in years:
            continue
        if normalized_model not in models:
            continue
        if normalized_market and market != normalized_market:
            continue
        if normalized_trim and normalized_trim not in trims:
            continue
        matching.append(chunk)

    score = max((chunk.similarity for chunk in matching), default=0.0)
    if not matching:
        return SpecEvidenceResult(False, 0.0, "no verified exact year/model/trim/market evidence")
    if score < min_similarity:
        return SpecEvidenceResult(False, score, "exact source similarity is below threshold")
    return SpecEvidenceResult(True, score, "exact vehicle specification evidence matched")
