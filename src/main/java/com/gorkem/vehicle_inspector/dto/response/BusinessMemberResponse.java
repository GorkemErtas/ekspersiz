package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.BusinessRole;

public record BusinessMemberResponse(
        Long id,
        Long userId,
        String fullName,
        String email,
        BusinessRole role
) {
}
