package com.gorkem.vehicle_inspector.dto.response;

import java.time.LocalDateTime;
import java.util.List;

public record VehicleOverviewResponse(
        VehicleResponse vehicle,
        String trackingStatus,
        String disclaimer,
        MaintenanceResponse latestMaintenance,
        List<ReminderResponse> upcomingReminders,
        Long latestInspectionId,
        String latestDamageSeverity,
        LocalDateTime latestInspectionAt
) {}
