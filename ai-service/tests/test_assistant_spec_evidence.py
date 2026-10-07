import unittest

from app.assistant.schemas import RetrievedChunk
from app.assistant.spec_evidence import (
    VehicleSpecIdentity,
    validate_vehicle_spec_evidence,
)


def chunk(*, similarity=0.9, authority="OFFICIAL", market="TR",
          years=(2020,), makes=("Toyota",), models=("Corolla",),
          trims=("Dream",), applies_all_trims=False):
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
            "vehicle_makes": list(makes),
            "vehicle_models": list(models),
            "vehicle_trims": list(trims),
            "applies_all_trims": applies_all_trims,
        },
    )


class VehicleSpecEvidenceTest(unittest.TestCase):
    def identity(self, *, trim="Dream", market="TR"):
        return VehicleSpecIdentity(2020, "Toyota", "Corolla", trim, market)

    def test_accepts_verified_exact_match(self):
        result = validate_vehicle_spec_evidence(self.identity(), [chunk()], 0.78)
        self.assertTrue(result.sufficient)
        self.assertEqual(0.9, result.score)

    def test_rejects_curated_source_for_exact_spec(self):
        result = validate_vehicle_spec_evidence(
            self.identity(), [chunk(authority="CURATED")], 0.78)
        self.assertFalse(result.sufficient)

    def test_rejects_wrong_make(self):
        result = validate_vehicle_spec_evidence(
            self.identity(), [chunk(makes=("Honda",))], 0.78)
        self.assertFalse(result.sufficient)

    def test_rejects_wrong_market(self):
        result = validate_vehicle_spec_evidence(
            self.identity(), [chunk(market="US")], 0.78)
        self.assertFalse(result.sufficient)

    def test_missing_market_defaults_to_tr(self):
        result = validate_vehicle_spec_evidence(
            self.identity(market=None), [chunk(market="TR")], 0.78)
        self.assertTrue(result.sufficient)

    def test_rejects_wrong_trim(self):
        result = validate_vehicle_spec_evidence(
            self.identity(), [chunk(trims=("Flame",))], 0.78)
        self.assertFalse(result.sufficient)

    def test_missing_trim_rejects_trim_specific_source(self):
        result = validate_vehicle_spec_evidence(
            self.identity(trim=None), [chunk(trims=("Dream",))], 0.78)
        self.assertFalse(result.sufficient)

    def test_missing_trim_accepts_all_trim_source(self):
        result = validate_vehicle_spec_evidence(
            self.identity(trim=None),
            [chunk(trims=(), applies_all_trims=True)],
            0.78,
        )
        self.assertTrue(result.sufficient)

    def test_rejects_low_similarity(self):
        result = validate_vehicle_spec_evidence(
            self.identity(), [chunk(similarity=0.70)], 0.78)
        self.assertFalse(result.sufficient)
        self.assertEqual(0.70, result.score)

    def test_requires_year_make_and_model(self):
        result = validate_vehicle_spec_evidence(
            VehicleSpecIdentity(model="Corolla"), [chunk()], 0.78)
        self.assertFalse(result.sufficient)


if __name__ == "__main__":
    unittest.main()
