package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.AiServiceException;
import com.gorkem.vehicle_inspector.service.GeminiAnalysisValidator;
import org.junit.jupiter.api.Test;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;

class GeminiAnalysisValidatorTest {
    @Test void successfulAndUncertainEvidenceAreValidDistinctOutcomes() {
        assertDoesNotThrow(() -> GeminiAnalysisValidator.validate(GeminiVisionFixtures.success()));
        assertDoesNotThrow(() -> GeminiAnalysisValidator.validate(GeminiVisionFixtures.unknown()));
        assertDoesNotThrow(() -> GeminiAnalysisValidator.validate(GeminiVisionFixtures.uncertain()));
    }
    @Test void cannotInventConfidenceOrConvertUncertainSeverityToMinor() {
        var result = GeminiVisionFixtures.success(); result.setConfidenceScore(.99);
        assertThrows(AiServiceException.class, () -> GeminiAnalysisValidator.validate(result));
        var unknown = GeminiVisionFixtures.unknown(); unknown.setDamageSeverity(DamageSeverity.MINOR);
        assertThrows(AiServiceException.class, () -> GeminiAnalysisValidator.validate(unknown));
    }
    @Test void cannotInventDefinitiveReplacementOrInconsistentParts() {
        var result = GeminiVisionFixtures.success();
        result.getRepairRecommendations().getFirst().setPartReplacementRequired(false);
        assertThrows(AiServiceException.class, () -> GeminiAnalysisValidator.validate(result));
        var wrongPart = GeminiVisionFixtures.success(); wrongPart.setAffectedParts(List.of(VehiclePart.HOOD));
        assertThrows(AiServiceException.class, () -> GeminiAnalysisValidator.validate(wrongPart));
    }
    @Test void missingFieldsAndLegacyDetectorResponsesCannotCreateNewAnalyses() {
        assertThrows(AiServiceException.class, () -> GeminiAnalysisValidator.validate(null));
        var missing = GeminiVisionFixtures.success(); missing.setAnalysisOutcome(null);
        assertThrows(AiServiceException.class, () -> GeminiAnalysisValidator.validate(missing));
        var legacy = GeminiVisionFixtures.success(); legacy.setSchemaVersion("hitl-v1");
        assertThrows(AiServiceException.class, () -> GeminiAnalysisValidator.validate(legacy));
    }
}
