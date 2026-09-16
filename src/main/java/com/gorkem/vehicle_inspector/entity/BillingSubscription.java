package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "billing_subscriptions",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_billing_subscriptions_user",
                columnNames = "user_id"
        )
)
public class BillingSubscription {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "product_id", length = 100)
    private String productId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private BillingSubscriptionStatus status;

    @Column(length = 30)
    private String store;

    @Column(name = "auto_renewing", nullable = false)
    private boolean autoRenewing;

    @Column(name = "sandbox", nullable = false)
    private boolean sandbox;

    @Column(name = "current_period_started_at")
    private LocalDateTime currentPeriodStartedAt;

    @Column(name = "current_period_ends_at")
    private LocalDateTime currentPeriodEndsAt;

    @Column(name = "management_url", length = 500)
    private String managementUrl;

    @Column(name = "last_synced_at", nullable = false)
    private LocalDateTime lastSyncedAt;

    protected BillingSubscription() {
    }

    public BillingSubscription(User user) {
        this.user = user;
        this.status = BillingSubscriptionStatus.EXPIRED;
        this.lastSyncedAt = LocalDateTime.now();
    }

    public void update(
            String productId,
            BillingSubscriptionStatus status,
            String store,
            boolean autoRenewing,
            boolean sandbox,
            LocalDateTime currentPeriodStartedAt,
            LocalDateTime currentPeriodEndsAt,
            String managementUrl,
            LocalDateTime lastSyncedAt
    ) {
        this.productId = productId;
        this.status = status;
        this.store = store;
        this.autoRenewing = autoRenewing;
        this.sandbox = sandbox;
        this.currentPeriodStartedAt = currentPeriodStartedAt;
        this.currentPeriodEndsAt = currentPeriodEndsAt;
        this.managementUrl = managementUrl;
        this.lastSyncedAt = lastSyncedAt;
    }

    public String getProductId() {
        return productId;
    }

    public BillingSubscriptionStatus getStatus() {
        return status;
    }

    public String getStore() {
        return store;
    }

    public boolean isAutoRenewing() {
        return autoRenewing;
    }

    public boolean isSandbox() {
        return sandbox;
    }

    public LocalDateTime getCurrentPeriodStartedAt() {
        return currentPeriodStartedAt;
    }

    public LocalDateTime getCurrentPeriodEndsAt() {
        return currentPeriodEndsAt;
    }

    public String getManagementUrl() {
        return managementUrl;
    }

    public LocalDateTime getLastSyncedAt() {
        return lastSyncedAt;
    }
}
