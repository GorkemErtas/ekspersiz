package com.gorkem.vehicle_inspector.dto.response;

public record PhotoAssessmentResponse(Boolean overviewUsable, Boolean detailUsable,
        Boolean sameVehicleAndArea) {}
