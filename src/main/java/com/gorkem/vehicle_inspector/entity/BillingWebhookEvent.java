package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "billing_webhook_events",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_billing_webhook_event_provider_id",
                columnNames = "provider_event_id"
        )
)
public class BillingWebhookEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "provider_event_id", nullable = false, length = 100)
    private String providerEventId;

    @Column(name = "event_type", nullable = false, length = 50)
    private String eventType;

    @Column(name = "app_user_id", length = 100)
    private String appUserId;

    @Column(name = "processed_at", nullable = false)
    private LocalDateTime processedAt;

    protected BillingWebhookEvent() {
    }

    public BillingWebhookEvent(
            String providerEventId,
            String eventType,
            String appUserId,
            LocalDateTime processedAt
    ) {
        this.providerEventId = providerEventId;
        this.eventType = eventType;
        this.appUserId = appUserId;
        this.processedAt = processedAt;
    }
}
