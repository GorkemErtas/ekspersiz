package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.DamageAssessmentRecordStatus;

import java.time.LocalDateTime;

public record DamageAssessmentRecordResponse(
        Long id,
        Long inspectionId,
        String recordNumber,
        DamageAssessmentRecordStatus status,
        Integer documentVersion,
        LocalDateTime incidentDateTime,
        String incidentCity,
        String incidentDistrict,
        String incidentAddress,
        String incidentDescription,
        String declarantFullName,
        LocalDateTime createdAt,
        LocalDateTime updatedAt,
        LocalDateTime finalizedAt
) {
}
