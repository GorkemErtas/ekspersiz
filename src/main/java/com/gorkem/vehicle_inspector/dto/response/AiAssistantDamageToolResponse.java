package com.gorkem.vehicle_inspector.dto.response;

import java.time.LocalDateTime;
import java.util.List;
public record AiAssistantDamageToolResponse(Long inspectionId, String severity, Double confidenceScore,
        String message, LocalDateTime completedAt, String schemaVersion, String modelVersion,
        List<String> damageTypes, List<String> affectedParts) {
    public AiAssistantDamageToolResponse(Long inspectionId, String severity, Double confidenceScore,
            String message, LocalDateTime completedAt) {
        this(inspectionId, severity, confidenceScore, message, completedAt, null, null, List.of(), List.of());
    }
}
