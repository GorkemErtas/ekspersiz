package com.gorkem.vehicle_inspector.client;

import java.time.Instant;

public record RevenueCatSubscription(
        String productId,
        Instant purchasedAt,
        Instant expiresAt,
        Instant gracePeriodExpiresAt,
        boolean autoRenewing,
        boolean billingIssue,
        boolean refunded,
        boolean sandbox,
        String store
) {
    public Instant accessEndsAt() {
        if (gracePeriodExpiresAt != null
                && (expiresAt == null || gracePeriodExpiresAt.isAfter(expiresAt))) {
            return gracePeriodExpiresAt;
        }

        return expiresAt;
    }
}
