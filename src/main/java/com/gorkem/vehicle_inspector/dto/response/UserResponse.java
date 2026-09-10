package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.Role;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

import java.time.LocalDateTime;

public class UserResponse {

    private final Long id;
    private final String fullName;
    private final String email;
    private final Role role;

    private final SubscriptionPlan subscriptionPlan;

    private final LocalDateTime subscriptionStartedAt;

    private final LocalDateTime subscriptionExpiresAt;

    public UserResponse(
            Long id,
            String fullName,
            String email,
            Role role,
            SubscriptionPlan subscriptionPlan,
            LocalDateTime subscriptionStartedAt,
            LocalDateTime subscriptionExpiresAt
    ) {
        this.id = id;
        this.fullName = fullName;
        this.email = email;
        this.role = role;
        this.subscriptionPlan = subscriptionPlan;
        this.subscriptionStartedAt =
                subscriptionStartedAt;
        this.subscriptionExpiresAt =
                subscriptionExpiresAt;
    }

    public Long getId() {
        return id;
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

    public LocalDateTime getSubscriptionStartedAt() {
        return subscriptionStartedAt;
    }

    public LocalDateTime getSubscriptionExpiresAt() {
        return subscriptionExpiresAt;
    }
}