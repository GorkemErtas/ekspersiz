package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

public record DamageAssessmentRecordRequest(
        @NotNull LocalDateTime incidentDateTime,
        @NotBlank @Size(max = 100) String incidentCity,
        @Size(max = 100) String incidentDistrict,
        @Size(max = 500) String incidentAddress,
        @NotBlank @Size(max = 3000) String incidentDescription,
        @NotBlank @Size(max = 150) String declarantFullName
) {
}
