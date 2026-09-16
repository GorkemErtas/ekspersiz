package com.gorkem.vehicle_inspector.dto.response;

import java.util.List;

public record BillingOverviewResponse(
        BillingStatusResponse status,
        List<BillingPlanResponse> plans
) {
}
