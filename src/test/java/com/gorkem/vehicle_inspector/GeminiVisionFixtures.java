package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.entity.*;
import java.util.List;

final class GeminiVisionFixtures {
    private GeminiVisionFixtures() {}
    static AiAnalysisResponse success() {
        var result = base();
        result.setAnalysisOutcome("DAMAGE_DETECTED");
        result.setDamageSeverity(DamageSeverity.MINOR);
        result.setVisualFindings(List.of(new VisualFindingResponse(DamageType.SCRATCH, VehiclePart.FRONT_BUMPER,
                DamageSeverity.MINOR, "Tampon yüzeyinde çizik görünümü mevcut.", RepairAction.PAINT_TOUCH_UP,
                "Boya rötuşu uygunluğu fiziksel incelemeyle değerlendirilebilir.", "UNDETERMINED", List.of("OVERVIEW", "DETAIL"))));
        result.setDamageTypes(List.of(DamageType.SCRATCH));
        result.setAffectedParts(List.of(VehiclePart.FRONT_BUMPER));
        var recommendation = new RepairRecommendationResponse();
        recommendation.setDamageType(DamageType.SCRATCH);
        recommendation.setRecommendedAction(RepairAction.PAINT_TOUCH_UP);
        recommendation.setPartReplacementRequired(null);
        recommendation.setAffectedParts(List.of(VehiclePart.FRONT_BUMPER));
        result.setRepairRecommendations(List.of(recommendation));
        return result;
    }
    static AiAnalysisResponse unknown() {
        var result = success();
        var item = result.getVisualFindings().getFirst();
        result.setDamageSeverity(DamageSeverity.UNKNOWN);
        result.setVisualFindings(List.of(new VisualFindingResponse(item.damageType(), item.affectedPart(),
                DamageSeverity.UNKNOWN, item.description(), item.recommendedAction(), item.repairNotes(),
                item.replacementAssessment(), item.evidenceImages())));
        return result;
    }
    static AiAnalysisResponse uncertain() {
        var result = base();
        result.setAnalysisOutcome("NEEDS_MORE_PHOTOS");
        result.setDamageSeverity(DamageSeverity.UNKNOWN);
        result.setAdditionalPhotoGuidance("Aynı hasarı genel görünüm ve net yakın detayla tekrar gösterin.");
        return result;
    }
    private static AiAnalysisResponse base() {
        var result = new AiAnalysisResponse();
        result.setSchemaVersion("gemini-vision-v1");
        result.setModelVersion("gemini-3.8-flash");
        result.setPhotoAssessment(new PhotoAssessmentResponse(true, true, true));
        result.setVisualFindings(List.of());
        result.setDetections(List.of()); result.setPartDetections(List.of());
        result.setDamageTypes(List.of()); result.setAffectedParts(List.of()); result.setRepairRecommendations(List.of());
        result.setAnalysisMessage("Bu değerlendirme fotoğraflarla sınırlıdır; fiziksel ekspertiz değildir.");
        result.setAdditionalPhotoGuidance("");
        return result;
    }
}
