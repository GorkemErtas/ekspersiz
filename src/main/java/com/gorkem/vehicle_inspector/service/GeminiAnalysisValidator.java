package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.AiServiceException;
import java.util.*;

/** Independent trust boundary for Python/LLM output. Historical reads do not use this validator. */
public final class GeminiAnalysisValidator {
    public static final String SCHEMA = "gemini-vision-v1";
    private GeminiAnalysisValidator() {}

    public static void validate(AiAnalysisResponse response) {
        if (response == null || !SCHEMA.equals(response.getSchemaVersion())
                || response.getModelVersion() == null || !response.getModelVersion().matches("gemini-[a-z0-9.-]{1,100}")
                || response.getDamageSeverity() == null || response.getDamageSeverity() == DamageSeverity.NONE
                || response.getConfidenceScore() != null
                || response.getDetections() == null || !response.getDetections().isEmpty()
                || response.getPartDetections() == null || !response.getPartDetections().isEmpty()
                || response.getVisualFindings() == null || response.getVisualFindings().size() > 8
                || response.getDamageTypes() == null || response.getAffectedParts() == null
                || response.getRepairRecommendations() == null
                || !text(response.getAnalysisMessage(), 10, 1000)
                || response.getAdditionalPhotoGuidance() == null || response.getAdditionalPhotoGuidance().length() > 400) invalid();
        var assessment = response.getPhotoAssessment();
        if (assessment == null || assessment.overviewUsable() == null || assessment.detailUsable() == null
                || assessment.sameVehicleAndArea() == null) invalid();
        if (!"DAMAGE_DETECTED".equals(response.getAnalysisOutcome())) {
            if (response.getAnalysisOutcome() == null || !Set.of("INCONCLUSIVE", "NEEDS_MORE_PHOTOS").contains(response.getAnalysisOutcome())
                    || response.getDamageSeverity() != DamageSeverity.UNKNOWN
                    || !response.getVisualFindings().isEmpty() || !response.getDamageTypes().isEmpty()
                    || !response.getAffectedParts().isEmpty() || !response.getRepairRecommendations().isEmpty()
                    || !text(response.getAdditionalPhotoGuidance(), 1, 400)) invalid();
            return;
        }
        if (!assessment.overviewUsable() || !assessment.detailUsable() || !assessment.sameVehicleAndArea()
                || !response.getAdditionalPhotoGuidance().isEmpty() || response.getVisualFindings().isEmpty()
                || response.getVisualFindings().size() != response.getRepairRecommendations().size()) invalid();
        Set<DamageType> types = new HashSet<>();
        Set<VehiclePart> parts = new HashSet<>();
        Set<String> distinct = new HashSet<>();
        DamageSeverity maximum = DamageSeverity.MINOR;
        boolean unknown = false;
        for (int i = 0; i < response.getVisualFindings().size(); i++) {
            var finding = response.getVisualFindings().get(i);
            if (finding == null || finding.damageType() == null || finding.damageType() == DamageType.NO_VISIBLE_DAMAGE
                    || finding.affectedPart() == null || finding.affectedPart().name().startsWith("BACK_")
                    || finding.severity() == null || finding.severity() == DamageSeverity.NONE
                    || !text(finding.description(), 10, 400) || !text(finding.repairNotes(), 10, 300)
                    || finding.recommendedAction() == null || finding.recommendedAction() == RepairAction.NO_ACTION
                    || finding.replacementAssessment() == null
                    || !Set.of("POSSIBLE", "NOT_INDICATED", "UNDETERMINED").contains(finding.replacementAssessment())
                    || finding.evidenceImages() == null || finding.evidenceImages().isEmpty() || finding.evidenceImages().size() > 2
                    || finding.evidenceImages().stream().anyMatch(e -> e == null || !Set.of("OVERVIEW", "DETAIL").contains(e))
                    || new HashSet<>(finding.evidenceImages()).size() != finding.evidenceImages().size()
                    || !distinct.add(finding.damageType()+":"+finding.affectedPart())) invalid();
            types.add(finding.damageType());
            if (finding.affectedPart() != VehiclePart.UNKNOWN) parts.add(finding.affectedPart());
            unknown |= finding.severity() == DamageSeverity.UNKNOWN;
            if (rank(finding.severity()) > rank(maximum)) maximum = finding.severity();
            var recommendation = response.getRepairRecommendations().get(i);
            if (recommendation == null || recommendation.getDamageType() != finding.damageType()
                    || recommendation.getRecommendedAction() != finding.recommendedAction()
                    || recommendation.getPartReplacementRequired() != null
                    || !Objects.equals(recommendation.getAffectedParts(), finding.affectedPart() == VehiclePart.UNKNOWN
                            ? List.of() : List.of(finding.affectedPart()))) invalid();
        }
        if (response.getDamageSeverity() != (unknown ? DamageSeverity.UNKNOWN : maximum)
                || !types.equals(new HashSet<>(response.getDamageTypes())) || response.getDamageTypes().size() != types.size()
                || !parts.equals(new HashSet<>(response.getAffectedParts())) || response.getAffectedParts().size() != parts.size()) invalid();
    }

    private static int rank(DamageSeverity value) {
        return switch (value) { case MINOR -> 1; case MODERATE -> 2; case SEVERE -> 3; default -> 0; };
    }
    private static boolean text(String value, int min, int max) {
        return value != null && !value.isBlank() && value.length() >= min && value.length() <= max;
    }
    private static void invalid() {
        throw new AiServiceException("Görsel analiz servisi geçerli ve tutarlı görsel kanıt döndürmedi; kredi tüketilmedi.");
    }
}
