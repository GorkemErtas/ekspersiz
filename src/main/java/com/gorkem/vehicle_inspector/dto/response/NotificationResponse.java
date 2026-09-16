package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.NotificationSeverity;
import com.gorkem.vehicle_inspector.entity.NotificationType;

import java.time.LocalDateTime;

public record NotificationResponse(
        Long id,
        Long vehicleId,
        NotificationType notificationType,
        NotificationSeverity severity,
        String title,
        String body,
        String navigationTarget,
        boolean read,
        LocalDateTime createdAt
) {
}
