package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record VehicleTrackingRequest(
        LocalDate lastMaintenanceDate,
        @Min(0) @Max(2_000_000) Integer lastMaintenanceMileage,
        LocalDate nextMaintenanceDate,
        @Min(0) @Max(2_000_000) Integer nextMaintenanceMileage,
        LocalDate vehicleInspectionDate,
        LocalDate trafficInsuranceExpiryDate,
        LocalDate comprehensiveInsuranceExpiryDate,
        LocalDate tireCheckDate,
        @Size(max = 1000) String notes
) {}
