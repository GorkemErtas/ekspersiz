package com.gorkem.vehicle_inspector.mapper;

import com.gorkem.vehicle_inspector.dto.response.DamageDetectionResponse;
import com.gorkem.vehicle_inspector.dto.response.DamageInspectionResponse;
import com.gorkem.vehicle_inspector.dto.response.DamageRepairRecommendationResponse;
import com.gorkem.vehicle_inspector.dto.response.InspectionReportResponse;
import com.gorkem.vehicle_inspector.entity.DamageInspection;
import com.gorkem.vehicle_inspector.entity.DamageType;
import com.gorkem.vehicle_inspector.entity.VehiclePart;

import java.util.List;
import java.util.Objects;

public final class DamageInspectionMapper {

    private static final double
            AFFECTED_PART_CONFIDENCE_THRESHOLD = 0.50;

    private DamageInspectionMapper() {
    }

    public static DamageInspectionResponse toResponse(
            DamageInspection inspection,
            InspectionReportResponse report
    ) {

        List<DamageDetectionResponse> detections =
                inspection.getDetections()
                        .stream()
                        .map(detection ->
                                new DamageDetectionResponse(
                                        detection.getId(),
                                        detection.getLabel(),
                                        detection.getConfidence(),
                                        detection.getAffectedPart(),
                                        detection.getX1(),
                                        detection.getY1(),
                                        detection.getX2(),
                                        detection.getY2()
                                )
                        )
                        .toList();

        List<VehiclePart> affectedParts =
                inspection.getDetections()
                        .stream()
                        .filter(detection ->
                                detection.getConfidence() != null
                                        && detection.getConfidence()
                                        >= AFFECTED_PART_CONFIDENCE_THRESHOLD
                        )
                        .map(detection ->
                                detection.getAffectedPart()
                        )
                        .filter(Objects::nonNull)
                        .filter(part ->
                                part != VehiclePart.UNKNOWN
                        )
                        .distinct()
                        .toList();

        List<DamageRepairRecommendationResponse>
                repairRecommendations =
                inspection.getRepairRecommendations()
                        .stream()
                        .map(recommendation ->
                                new DamageRepairRecommendationResponse(
                                        recommendation.getDamageType(),
                                        recommendation.getRecommendedAction(),
                                        recommendation.getPartReplacementRequired(),
                                        recommendation.getAffectedParts()
                                                .stream()
                                                .toList()
                                )
                        )
                        .toList();

        List<DamageType> damageTypes =
                repairRecommendations
                        .stream()
                        .map(
                                DamageRepairRecommendationResponse
                                        ::damageType
                        )
                        .filter(Objects::nonNull)
                        .distinct()
                        .toList();

        return new DamageInspectionResponse(
                inspection.getId(),
                inspection.getVehicle().getId(),
                inspection.getVehicle().getPlate(),
                inspection.getVehicle().getBrand(),
                inspection.getVehicle().getModel(),
                inspection.getVehicle().getModelYear(),
                inspection.getVehicle().getMileage(),
                inspection.getUser().getId(),
                inspection.getImagePath(),
                inspection.getStatus(),
                inspection.getReportStatus(),
                inspection.getReportMessage(),
                inspection.getDamageSeverity(),
                damageTypes,
                affectedParts,
                repairRecommendations,
                inspection.getConfidenceScore(),
                inspection.getAnalysisMessage(),
                inspection.getCreatedAt(),
                inspection.getCompletedAt(),
                detections,
                report,
                inspection.getLocationCity(),
                inspection.getLocationLatitude(),
                inspection.getLocationLongitude()
        );
    }
}
