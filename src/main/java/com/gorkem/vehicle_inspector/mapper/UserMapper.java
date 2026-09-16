package com.gorkem.vehicle_inspector.mapper;

import com.gorkem.vehicle_inspector.dto.response.UserResponse;
import com.gorkem.vehicle_inspector.dto.response.BusinessAccountResponse;
import com.gorkem.vehicle_inspector.entity.User;

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
        return new UserResponse(
                user.getId(),
                user.getFullName(),
                user.getEmail(),
                user.getSubscriptionPlan(),
                user.getSubscriptionStartedAt(),
                user.getSubscriptionExpiresAt(),
                businessAccount
        );
    }
}
