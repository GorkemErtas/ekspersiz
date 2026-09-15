package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.BusinessRole;

public record BusinessAccountResponse(
        Long id,
        String companyName,
        BusinessRole role
) {
}