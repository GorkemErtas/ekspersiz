package com.gorkem.vehicle_inspector.mapper;

import com.gorkem.vehicle_inspector.dto.response.UserResponse;
import com.gorkem.vehicle_inspector.dto.response.BusinessAccountResponse;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

public final class UserMapper {

    private UserMapper() {
    }

    public static UserResponse toResponse(
            User user
    ) {
        return toResponse(user, null);
    }

    public static UserResponse toResponse(
            User user,
            BusinessAccountResponse businessAccount
    ) {
        return toResponse(
                user,
                user.getSubscriptionPlan(),
                businessAccount
        );
    }

    public static UserResponse toResponse(
            User user,
            SubscriptionPlan effectivePlan,
            BusinessAccountResponse businessAccount
    ) {
        return new UserResponse(
                user.getId(),
                user.getFullName(),
                user.getEmail(),
                effectivePlan,
                user.getSubscriptionStartedAt(),
                user.getSubscriptionExpiresAt(),
                businessAccount
        );
    }
}
