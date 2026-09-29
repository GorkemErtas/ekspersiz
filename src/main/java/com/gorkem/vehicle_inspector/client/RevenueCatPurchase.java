package com.gorkem.vehicle_inspector.client;

import java.time.Instant;

public record RevenueCatPurchase(
        String productId,
        String transactionId,
        Instant purchasedAt,
        boolean sandbox,
        String store
) {
}
