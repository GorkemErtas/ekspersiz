package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.DamageSeverity;
import com.gorkem.vehicle_inspector.entity.DamageType;
import com.gorkem.vehicle_inspector.entity.InspectionStatus;
import com.gorkem.vehicle_inspector.entity.VehiclePart;
import com.gorkem.vehicle_inspector.entity.ReportStatus;

import java.time.LocalDateTime;
import java.util.List;

public class DamageInspectionResponse {

    private final Long id;
    private final Long vehicleId;
    private final String vehiclePlate;
    private final String vehicleBrand;
    private final String vehicleModel;
    private final Integer vehicleModelYear;
    private final Integer vehicleMileage;
    private final Long userId;
    private final String imagePath;
    private final InspectionStatus status;

    private final DamageSeverity damageSeverity;
    private final List<DamageType> damageTypes;
    private final List<VehiclePart> affectedParts;

    private final List<DamageRepairRecommendationResponse>
            repairRecommendations;

    private final Double confidenceScore;
    private final String analysisMessage;

    private final LocalDateTime createdAt;
    private final LocalDateTime completedAt;

    private final List<DamageDetectionResponse> detections;

    private final InspectionReportResponse report;
    private final String locationCity;

    private final ReportStatus reportStatus;
    private final String reportMessage;

    private final Double locationLatitude;
    private final Double locationLongitude;

    public DamageInspectionResponse(
            Long id,
            Long vehicleId,
            String vehiclePlate,
            String vehicleBrand,
            String vehicleModel,
            Integer vehicleModelYear,
            Integer vehicleMileage,
            Long userId,
            String imagePath,
            InspectionStatus status,
            ReportStatus reportStatus,
            String reportMessage,
            DamageSeverity damageSeverity,
            List<DamageType> damageTypes,
            List<VehiclePart> affectedParts,
            List<DamageRepairRecommendationResponse> repairRecommendations,
            Double confidenceScore,
            String analysisMessage,
            LocalDateTime createdAt,
            LocalDateTime completedAt,
            List<DamageDetectionResponse> detections,
            InspectionReportResponse report,
            String locationCity,
            Double locationLatitude,
            Double locationLongitude
    ) {
        this.id = id;
        this.vehicleId = vehicleId;
        this.vehiclePlate = vehiclePlate;
        this.vehicleBrand = vehicleBrand;
        this.vehicleModel = vehicleModel;
        this.vehicleModelYear = vehicleModelYear;
        this.vehicleMileage = vehicleMileage;
        this.userId = userId;
        this.imagePath = imagePath;
        this.status = status;
        this.reportStatus = reportStatus;
        this.reportMessage = reportMessage;

        this.damageSeverity = damageSeverity;
        this.damageTypes = damageTypes;
        this.affectedParts = affectedParts;

        this.repairRecommendations =
                repairRecommendations;

        this.confidenceScore = confidenceScore;
        this.analysisMessage = analysisMessage;

        this.createdAt = createdAt;
        this.completedAt = completedAt;

        this.detections = detections;
        this.report = report;
        this.locationCity = locationCity;

        this.locationLatitude = locationLatitude;

        this.locationLongitude = locationLongitude;
    }

    public Long getId() {
        return id;
    }

    public Long getVehicleId() {
        return vehicleId;
    }

    public String getVehiclePlate() {
        return vehiclePlate;
    }

    public String getVehicleBrand() { return vehicleBrand; }

    public String getVehicleModel() { return vehicleModel; }

    public Integer getVehicleModelYear() { return vehicleModelYear; }

    public Integer getVehicleMileage() { return vehicleMileage; }

    public Long getUserId() {
        return userId;
    }

    public String getImagePath() {
        return imagePath;
    }

    public InspectionStatus getStatus() {
        return status;
    }

    public ReportStatus getReportStatus() {
        return reportStatus;
    }

    public String getReportMessage() {
        return reportMessage;
    }

    public DamageSeverity getDamageSeverity() {
        return damageSeverity;
    }

    public List<DamageType> getDamageTypes() {
        return damageTypes;
    }

    public List<VehiclePart> getAffectedParts() {
        return affectedParts;
    }

    public List<DamageRepairRecommendationResponse>
    getRepairRecommendations() {
        return repairRecommendations;
    }

    public Double getConfidenceScore() {
        return confidenceScore;
    }

    public String getAnalysisMessage() {
        return analysisMessage;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getCompletedAt() {
        return completedAt;
    }

    public List<DamageDetectionResponse> getDetections() {
        return detections;
    }

    public InspectionReportResponse getReport() {
        return report;
    }

    public String getLocationCity() {
        return locationCity;
    }

    public Double getLocationLatitude() {
        return locationLatitude;
    }

    public Double getLocationLongitude() {
        return locationLongitude;
    }
}
