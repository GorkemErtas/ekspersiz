package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

public record AnalysisQuotaResponse(
        SubscriptionPlan plan,
        long used,
        int baseLimit,
        boolean rewardedClaimed,
        boolean rewardedEligible,
        int totalLimit,
        long remaining
) {
}
