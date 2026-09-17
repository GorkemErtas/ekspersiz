package com.gorkem.vehicle_inspector.dto.response;

public record ImageQualityResponse(
        boolean suitable,
        String code,
        String message
) {
}
