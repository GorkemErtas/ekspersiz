package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.DamageSeverity;
import com.gorkem.vehicle_inspector.entity.DamageType;
import com.gorkem.vehicle_inspector.entity.RepairAction;
import com.gorkem.vehicle_inspector.entity.VehiclePart;
import java.util.List;

public class AiAnalysisResponse {
    private List<VisualFindingResponse> visualFindings;
    private PhotoAssessmentResponse photoAssessment;
    private String additionalPhotoGuidance;

    public List<VisualFindingResponse> getVisualFindings() { return visualFindings; }
    public void setVisualFindings(List<VisualFindingResponse> value) { visualFindings = value; }
    public PhotoAssessmentResponse getPhotoAssessment() { return photoAssessment; }
    public void setPhotoAssessment(PhotoAssessmentResponse value) { photoAssessment = value; }
    public String getAdditionalPhotoGuidance() { return additionalPhotoGuidance; }
    public void setAdditionalPhotoGuidance(String value) { additionalPhotoGuidance = value; }
    private String schemaVersion;
    private String modelVersion;
    private String analysisOutcome;
    private List<Object> partDetections;


    private DamageSeverity damageSeverity;

    private Double confidenceScore;

    private String analysisMessage;

    private List<Object> detections;

    private List<VehiclePart> affectedParts;

    private List<DamageType> damageTypes;

    private List<RepairRecommendationResponse>
            repairRecommendations;

    public AiAnalysisResponse() {
    }

    public DamageSeverity getDamageSeverity() {
        return damageSeverity;
    }

    public void setDamageSeverity(
            DamageSeverity damageSeverity
    ) {
        this.damageSeverity = damageSeverity;
    }

    public Double getConfidenceScore() {
        return confidenceScore;
    }

    public void setConfidenceScore(
            Double confidenceScore
    ) {
        this.confidenceScore = confidenceScore;
    }

    public String getAnalysisMessage() {
        return analysisMessage;
    }

    public void setAnalysisMessage(
            String analysisMessage
    ) {
        this.analysisMessage = analysisMessage;
    }

    public List<Object> getDetections() {
        return detections;
    }

    public void setDetections(
            List<Object> detections
    ) {
        this.detections = detections;
    }

    public List<VehiclePart> getAffectedParts() {
        return affectedParts;
    }

    public void setAffectedParts(
            List<VehiclePart> affectedParts
    ) {
        this.affectedParts = affectedParts;
    }

    public List<DamageType> getDamageTypes() {
        return damageTypes;
    }

    public void setDamageTypes(
            List<DamageType> damageTypes
    ) {
        this.damageTypes = damageTypes;
    }

    public List<RepairRecommendationResponse>
    getRepairRecommendations() {
        return repairRecommendations;
    }

    public void setRepairRecommendations(
            List<RepairRecommendationResponse>
                    repairRecommendations
    ) {
        this.repairRecommendations =
                repairRecommendations;
    }

    public String getSchemaVersion() { return schemaVersion; }
    public void setSchemaVersion(String value) { this.schemaVersion = value; }
    public String getModelVersion() { return modelVersion; }
    public void setModelVersion(String value) { this.modelVersion = value; }
    public String getAnalysisOutcome() { return analysisOutcome; }
    public void setAnalysisOutcome(String value) { this.analysisOutcome = value; }
    public List<Object> getPartDetections() { return partDetections; }
    public void setPartDetections(List<Object> value) { this.partDetections = value; }
}
