package com.gorkem.vehicle_inspector.dto.request;

import com.gorkem.vehicle_inspector.entity.MaintenanceType;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;

public record MaintenanceRequest(
        @NotNull MaintenanceType maintenanceType,
        @NotNull LocalDate maintenanceDate,
        @NotNull @Min(0) @Max(2_000_000) Integer mileage,
        @DecimalMin("0.00") BigDecimal cost,
        @Size(max = 1000) String note,
        LocalDate nextRecommendedDate,
        @Min(0) @Max(2_000_000) Integer nextRecommendedMileage
) {}
