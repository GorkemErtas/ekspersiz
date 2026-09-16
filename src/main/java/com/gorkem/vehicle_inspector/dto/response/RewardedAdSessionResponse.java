package com.gorkem.vehicle_inspector.dto.response;

import java.time.LocalDateTime;

public record RewardedAdSessionResponse(
        String customData,
        String userId,
        LocalDateTime expiresAt
) {
}
