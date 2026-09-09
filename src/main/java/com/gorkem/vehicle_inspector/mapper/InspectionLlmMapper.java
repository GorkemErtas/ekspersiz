package com.gorkem.vehicle_inspector.mapper;

import com.gorkem.vehicle_inspector.dto.llm.DamageContext;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.VehicleContext;
import com.gorkem.vehicle_inspector.entity.DamageInspection;
import com.gorkem.vehicle_inspector.entity.DamageRepairRecommendation;
import com.gorkem.vehicle_inspector.entity.VehiclePart;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

public final class InspectionLlmMapper {

    private InspectionLlmMapper() {
    }

    public static InspectionLlmRequest toRequest(
            DamageInspection inspection
    ) {
        if (inspection == null) {
            throw new IllegalArgumentException(
                    "İnceleme bilgisi boş olamaz."
            );
        }

        if (inspection.getVehicle() == null) {
            throw new IllegalStateException(
                    "İncelemeye ait araç bilgisi bulunamadı."
            );
        }

        VehicleContext vehicle =
                new VehicleContext(
                        inspection.getVehicle().getBrand(),
                        inspection.getVehicle().getModel(),
                        inspection.getVehicle().getModelYear(),
                        inspection.getVehicle().getMileage()
                );

        List<DamageContext> damages;

        if (inspection.getRepairRecommendations() == null) {

            damages = Collections.emptyList();

        } else {

            damages =
                    inspection.getRepairRecommendations()
                            .stream()
                            .filter(Objects::nonNull)
                            .map(
                                    InspectionLlmMapper
                                            ::toDamageContext
                            )
                            .toList();
        }

        return new InspectionLlmRequest(
                vehicle,
                inspection.getLocationCity(),
                inspection.getCompletedAt() != null
                        ? inspection.getCompletedAt().toLocalDate()
                        : LocalDate.now(),
                inspection.getDamageSeverity(),
                inspection.getConfidenceScore(),
                inspection.getAnalysisMessage(),
                damages
        );
    }

    private static DamageContext toDamageContext(
            DamageRepairRecommendation recommendation
    ) {
        List<VehiclePart> affectedParts;

        if (recommendation.getAffectedParts() == null) {

            affectedParts = Collections.emptyList();

        } else {

            affectedParts =
                    recommendation.getAffectedParts()
                            .stream()
                            .filter(Objects::nonNull)
                            .toList();
        }

        return new DamageContext(
                recommendation.getDamageType(),
                recommendation.getRecommendedAction(),
                recommendation.getPartReplacementRequired(),
                affectedParts
        );
    }
}