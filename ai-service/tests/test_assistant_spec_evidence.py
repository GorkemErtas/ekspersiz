import unittest

from app.assistant.schemas import RetrievedChunk
from app.assistant.spec_evidence import (
    VehicleSpecIdentity,
    validate_vehicle_spec_evidence,
)


def chunk(*, similarity=0.9, authority="OFFICIAL", market="TR",
          years=(2020,), models=("Corolla",), trims=("Dream",)):
    return RetrievedChunk(
        chunk_id=1,
        document_slug="corolla-spec",
        title="Corolla specification",
        category="VEHICLE_SPEC",
        content="Verified specification.",
        similarity=similarity,
        market=market,
        authority=authority,
        source_version="2020-tr",
        metadata={
            "vehicle_years": list(years),
            "vehicle_models": list(models),
            "vehicle_trims": list(trims),
        },
    )


class VehicleSpecEvidenceTest(unittest.TestCase):
    def test_accepts_verified_exact_match(self):
        result = validate_vehicle_spec_evidence(
            VehicleSpecIdentity(2020, "Corolla", "Dream", "TR"),
            [chunk()],
            0.78,
        )
        self.assertTrue(result.sufficient)
        self.assertEqual(0.9, result.score)

    def test_rejects_curated_source_for_exact_spec(self):
        result = validate_vehicle_spec_evidence(
            VehicleSpecIdentity(2020, "Corolla", "Dream", "TR"),
            [chunk(authority="CURATED")],
            0.78,
        )
        self.assertFalse(result.sufficient)

    def test_rejects_wrong_market(self):
        result = validate_vehicle_spec_evidence(
            VehicleSpecIdentity(2020, "Corolla", "Dream", "TR"),
            [chunk(market="US")],
            0.78,
        )
        self.assertFalse(result.sufficient)

    def test_rejects_wrong_trim(self):
        result = validate_vehicle_spec_evidence(
            VehicleSpecIdentity(2020, "Corolla", "Dream", "TR"),
            [chunk(trims=("Flame",))],
            0.78,
        )
        self.assertFalse(result.sufficient)

    def test_rejects_low_similarity(self):
        result = validate_vehicle_spec_evidence(
            VehicleSpecIdentity(2020, "Corolla", "Dream", "TR"),
            [chunk(similarity=0.70)],
            0.78,
        )
        self.assertFalse(result.sufficient)
        self.assertEqual(0.70, result.score)

    def test_requires_year_and_model(self):
        result = validate_vehicle_spec_evidence(
            VehicleSpecIdentity(model="Corolla"),
            [chunk()],
            0.78,
        )
        self.assertFalse(result.sufficient)


if __name__ == "__main__":
    unittest.main()
