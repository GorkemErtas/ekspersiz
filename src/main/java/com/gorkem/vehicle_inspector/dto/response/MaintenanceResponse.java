package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.MaintenanceType;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record MaintenanceResponse(
        Long id, Long vehicleId, MaintenanceType maintenanceType,
        LocalDate maintenanceDate, Integer mileage, BigDecimal cost,
        String note, LocalDate nextRecommendedDate,
        Integer nextRecommendedMileage, Integer intervalMonths,
        Integer intervalMileage, Long createdByUserId,
        String createdByName, LocalDateTime createdAt
) {}
