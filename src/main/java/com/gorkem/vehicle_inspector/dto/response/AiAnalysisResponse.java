package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.DamageSeverity;
import com.gorkem.vehicle_inspector.entity.DamageType;
import com.gorkem.vehicle_inspector.entity.RepairAction;
import com.gorkem.vehicle_inspector.entity.VehiclePart;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public class AiAnalysisResponse {
    private String schemaVersion;
    private String modelVersion;
    private String analysisOutcome;
    private Integer imageWidth;
    private Integer imageHeight;
    private List<DetectedObjectResponse> partDetections;


    private DamageSeverity damageSeverity;

    private Double confidenceScore;

    private String analysisMessage;

    private List<DetectedObjectResponse> detections;

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

    public List<DetectedObjectResponse> getDetections() {
        return detections;
    }

    public void setDetections(
            List<DetectedObjectResponse> detections
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
    public Integer getImageWidth() { return imageWidth; }
    public void setImageWidth(Integer value) { this.imageWidth = value; }
    public Integer getImageHeight() { return imageHeight; }
    public void setImageHeight(Integer value) { this.imageHeight = value; }
    public List<DetectedObjectResponse> getPartDetections() { return partDetections; }
    public void setPartDetections(List<DetectedObjectResponse> value) { this.partDetections = value; }
}
