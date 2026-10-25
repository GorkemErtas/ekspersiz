package com.gorkem.vehicle_inspector.dto.llm;

import com.gorkem.vehicle_inspector.entity.DamageSeverity;

import java.time.LocalDate;
import java.util.List;

public record InspectionLlmRequest(
        VehicleContext vehicle,
        String city,
        LocalDate analysisDate,
        DamageSeverity damageSeverity,
        Double confidenceScore,
        String analysisMessage,
        List<DamageContext> damages,
        List<com.gorkem.vehicle_inspector.dto.response.VisualFindingResponse> visualFindings
) {
    public InspectionLlmRequest(VehicleContext vehicle, String city, LocalDate analysisDate,
            DamageSeverity damageSeverity, Double confidenceScore, String analysisMessage,
            List<DamageContext> damages) {
        this(vehicle, city, analysisDate, damageSeverity, confidenceScore, analysisMessage, damages, List.of());
    }
}
