package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

public record AnalysisQuotaResponse(
        SubscriptionPlan plan,
        long used,
        int limit,
        long remaining
) {
}
