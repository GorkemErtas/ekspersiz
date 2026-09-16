package com.gorkem.vehicle_inspector.dto.response;

import java.time.LocalDateTime;

public record VehicleHistoryItemResponse(
        String type, Long referenceId, String title,
        String description, LocalDateTime occurredAt
) {}
