package com.gorkem.vehicle_inspector.client;

import java.time.Instant;

public record RevenueCatPurchase(
        String productId,
        String transactionId,
        Instant purchasedAt,
        boolean sandbox,
        String store,
        boolean refunded
) {
    public RevenueCatPurchase(String productId,String transactionId,Instant purchasedAt,boolean sandbox,String store) {
        this(productId,transactionId,purchasedAt,sandbox,store,false);
    }
}
