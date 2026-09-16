package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.BillingSubscriptionStatus;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

import java.time.LocalDateTime;

public record BillingStatusResponse(
        String billingCustomerId,
        SubscriptionPlan currentPlan,
        BillingSubscriptionStatus status,
        String productId,
        boolean autoRenewing,
        boolean sandbox,
        LocalDateTime currentPeriodEndsAt,
        String managementUrl,
        LocalDateTime lastSyncedAt
) {
}
