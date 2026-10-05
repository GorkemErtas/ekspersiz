package com.gorkem.vehicle_inspector.dto.response;

import java.time.LocalDateTime;
public record AiAssistantDamageToolResponse(Long inspectionId, String severity, Double confidenceScore, String message, LocalDateTime completedAt) {}
