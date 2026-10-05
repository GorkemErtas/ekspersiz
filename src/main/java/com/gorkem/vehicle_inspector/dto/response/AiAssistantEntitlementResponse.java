package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.AiAssistantAccessStatus;
import java.time.LocalDateTime;

public record AiAssistantEntitlementResponse(
        AiAssistantAccessStatus status,
        boolean canAsk,
        int dailyLimit,
        int usedToday,
        int remainingToday,
        int outOfScopeAttemptsToday,
        LocalDateTime trialExpiresAt,
        LocalDateTime subscriptionExpiresAt,
        LocalDateTime lockedUntil
) {}
