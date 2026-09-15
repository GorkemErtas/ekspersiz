package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

public record BusinessAccountResponse(
        Long id,
        String companyName,
        BusinessRole role,
        SubscriptionPlan subscriptionPlan
) {
}