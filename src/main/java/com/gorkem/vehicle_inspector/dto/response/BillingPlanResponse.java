package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

import java.math.BigDecimal;
import java.util.List;

public record BillingPlanResponse(
        SubscriptionPlan plan,
        String title,
        String description,
        String productId,
        String packageIdentifier,
        BigDecimal fallbackMonthlyPrice,
        String currency,
        boolean highlighted,
        List<String> features
) {
}
