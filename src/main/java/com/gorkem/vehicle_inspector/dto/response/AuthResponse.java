package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.AccountType;

public class AuthResponse {

    private final String accessToken;
    private final String tokenType;
    private final Long expiresIn;
    private final Long userId;
    private final String fullName;
    private final String email;
    private final AccountType accountType;
    private final SubscriptionPlan subscriptionPlan;

    public AuthResponse(
            String accessToken,
            String tokenType,
            Long expiresIn,
            Long userId,
            String fullName,
            String email,
            AccountType accountType,
            SubscriptionPlan subscriptionPlan
    ) {
        this.accessToken = accessToken;
        this.tokenType = tokenType;
        this.expiresIn = expiresIn;
        this.userId = userId;
        this.fullName = fullName;
        this.email = email;
        this.accountType = accountType;
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

    public AccountType getAccountType() {
        return accountType;
    }

    public SubscriptionPlan getSubscriptionPlan() {
        return subscriptionPlan;
    }
}