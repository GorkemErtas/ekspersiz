package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "users",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_users_email",
                        columnNames = "email"
                )
        }
)
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(
            name = "full_name",
            nullable = false,
            length = 100
    )
    private String fullName;

    @Column(
            nullable = false,
            length = 150
    )
    private String email;

    @Column(
            nullable = false,
            length = 100
    )
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(
            nullable = false,
            length = 20
    )
    private Role role;

    @Enumerated(EnumType.STRING)
    @Column(
            name = "subscription_plan",
            nullable = false,
            length = 20
    )
    private SubscriptionPlan subscriptionPlan;

    @Column(
            name = "subscription_started_at"
    )
    private LocalDateTime subscriptionStartedAt;

    @Column(
            name = "subscription_expires_at"
    )
    private LocalDateTime subscriptionExpiresAt;

    @Column(
            name = "email_verified",
            nullable = false,
            columnDefinition = "boolean default true"
    )
    private boolean emailVerified;

    @Column(
            name = "email_verification_code_hash",
            length = 100
    )
    private String emailVerificationCodeHash;

    @Column(
            name = "email_verification_code_expires_at"
    )
    private LocalDateTime emailVerificationCodeExpiresAt;

    protected User() {
    }

    public User(
            String fullName,
            String email,
            String password,
            Role role
    ) {
        this.fullName = fullName;
        this.email = email;
        this.password = password;
        this.role = role;

        this.subscriptionPlan =
                SubscriptionPlan.FREE;

        this.emailVerified = false;
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

    public String getPassword() {
        return password;
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

    public boolean isEmailVerified() {
        return emailVerified;
    }

    public String getEmailVerificationCodeHash() {
        return emailVerificationCodeHash;
    }

    public LocalDateTime getEmailVerificationCodeExpiresAt() {
        return emailVerificationCodeExpiresAt;
    }

    public void setFullName(
            String fullName
    ) {
        this.fullName = fullName;
    }

    public void setEmail(
            String email
    ) {
        this.email = email;
    }

    public void setPassword(
            String password
    ) {
        this.password = password;
    }

    public void setRole(
            Role role
    ) {
        this.role = role;
    }

    public void setSubscriptionPlan(
            SubscriptionPlan subscriptionPlan
    ) {
        this.subscriptionPlan =
                subscriptionPlan;
    }

    public void setSubscriptionStartedAt(
            LocalDateTime subscriptionStartedAt
    ) {
        this.subscriptionStartedAt =
                subscriptionStartedAt;
    }

    public void setSubscriptionExpiresAt(
            LocalDateTime subscriptionExpiresAt
    ) {
        this.subscriptionExpiresAt =
                subscriptionExpiresAt;
    }

    public void setEmailVerificationCode(
            String emailVerificationCodeHash,
            LocalDateTime emailVerificationCodeExpiresAt
    ) {
        this.emailVerificationCodeHash =
                emailVerificationCodeHash;
        this.emailVerificationCodeExpiresAt =
                emailVerificationCodeExpiresAt;
    }

    public void markEmailVerified() {
        this.emailVerified = true;
        this.emailVerificationCodeHash = null;
        this.emailVerificationCodeExpiresAt = null;
    }

    public boolean isEmailVerificationCodeExpired() {
        return emailVerificationCodeExpiresAt == null
                || emailVerificationCodeExpiresAt
                .isBefore(LocalDateTime.now());
    }

    public boolean hasActiveSubscription() {
        if (subscriptionPlan == null
                || subscriptionPlan
                == SubscriptionPlan.FREE) {

            return false;
        }

        if (subscriptionExpiresAt == null) {
            return true;
        }

        return subscriptionExpiresAt
                .isAfter(LocalDateTime.now());
    }
}