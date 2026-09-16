package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

public class AuthResponse {

    private final String accessToken;
    private final String tokenType;
    private final Long expiresIn;
    private final Long userId;
    private final String fullName;
    private final String email;
    private final SubscriptionPlan subscriptionPlan;
    private final BusinessAccountResponse businessAccount;

    public AuthResponse(
            String accessToken,
            String tokenType,
            Long expiresIn,
            Long userId,
            String fullName,
            String email,
            SubscriptionPlan subscriptionPlan,
            BusinessAccountResponse businessAccount
    ) {
        this.accessToken = accessToken;
        this.tokenType = tokenType;
        this.expiresIn = expiresIn;
        this.userId = userId;
        this.fullName = fullName;
        this.email = email;
        this.subscriptionPlan =
                subscriptionPlan;
        this.businessAccount = businessAccount;
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

    public SubscriptionPlan getSubscriptionPlan() {
        return subscriptionPlan;
    }

    public BusinessAccountResponse getBusinessAccount() {
        return businessAccount;
    }
}
