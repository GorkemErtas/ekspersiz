package com.gorkem.vehicle_inspector.client;

import java.util.List;

public record RevenueCatCustomer(
        List<RevenueCatSubscription> subscriptions,
        List<RevenueCatPurchase> purchases,
        String managementUrl
) {
}
