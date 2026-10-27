package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.BusinessRole;

public record BusinessAccountResponse(
        Long id,
        String companyName,
        BusinessRole role,
        boolean sandbox
) {
    public BusinessAccountResponse(Long id, String companyName, BusinessRole role) {
        this(id, companyName, role, false);
    }
}
