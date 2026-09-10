package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.Role;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

public class AuthResponse {

    private final String accessToken;
    private final String tokenType;
    private final Long expiresIn;
    private final Long userId;
    private final String fullName;
    private final String email;
    private final Role role;
    private final SubscriptionPlan subscriptionPlan;

    public AuthResponse(
            String accessToken,
            String tokenType,
            Long expiresIn,
            Long userId,
            String fullName,
            String email,
            Role role,
            SubscriptionPlan subscriptionPlan
    ) {
        this.accessToken = accessToken;
        this.tokenType = tokenType;
        this.expiresIn = expiresIn;
        this.userId = userId;
        this.fullName = fullName;
        this.email = email;
        this.role = role;
        this.subscriptionPlan =
                subscriptionPlan;
    }

    public String getAccessToken() {
        return accessToken;
    }

    public String getTokenType() {
        return tokenType;
    }

    public Long getExpiresIn() {
        return expiresIn;
    }

    public Long getUserId() {
        return userId;
    }

    public String getFullName() {
        return fullName;
    }

    public String getEmail() {
        return email;
    }

    public Role getRole() {
        return role;
    }

    public SubscriptionPlan getSubscriptionPlan() {
        return subscriptionPlan;
    }
}