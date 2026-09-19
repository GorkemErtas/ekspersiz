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

        // Kullanıcının girdiği son araç muayene tarihi.
        // Sonraki muayene tarihi backend tarafından firstInspection
        // değerine göre +3 veya +2 yıl olarak hesaplanır.
        LocalDate vehicleInspectionDate,

        LocalDate trafficInsuranceExpiryDate,
        LocalDate comprehensiveInsuranceExpiryDate,
        LocalDate tireCheckDate,

        @Size(max = 1000) String notes,

        @Min(1) @Max(600) Integer maintenanceIntervalMonths,
        @Min(1) @Max(2_000_000) Integer maintenanceIntervalMileage,

        Boolean firstInspection
) {

    public VehicleTrackingRequest(
            LocalDate lastMaintenanceDate,
            Integer lastMaintenanceMileage,
            LocalDate nextMaintenanceDate,
            Integer nextMaintenanceMileage,
            LocalDate vehicleInspectionDate,
            LocalDate trafficInsuranceExpiryDate,
            LocalDate comprehensiveInsuranceExpiryDate,
            LocalDate tireCheckDate,
            String notes
    ) {
        this(
                lastMaintenanceDate,
                lastMaintenanceMileage,
                nextMaintenanceDate,
                nextMaintenanceMileage,
                vehicleInspectionDate,
                trafficInsuranceExpiryDate,
                comprehensiveInsuranceExpiryDate,
                tireCheckDate,
                notes,
                null,
                null,
                null
        );
    }
}