package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "app_notifications", uniqueConstraints = @UniqueConstraint(
        name = "uk_notification_user_event", columnNames = {"user_id", "event_key"}))
public class AppNotification {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicle_id")
    private Vehicle vehicle;

    @Column(name = "reminder_id")
    private Long reminderId;

    @Column(name = "event_key", nullable = false, length = 160)
    private String eventKey;

    @Enumerated(EnumType.STRING)
    @Column(name = "notification_type", nullable = false, length = 40)
    private NotificationType notificationType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private NotificationSeverity severity;

    @Column(nullable = false, length = 160)
    private String title;

    @Column(nullable = false, length = 500)
    private String body;

    @Column(name = "navigation_target", length = 200)
    private String navigationTarget;

    @Column(name = "read_at")
    private LocalDateTime readAt;

    @Column(name = "push_attempted_at")
    private LocalDateTime pushAttemptedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    protected AppNotification() {
    }

    public AppNotification(User user, Vehicle vehicle, VehicleReminder reminder,
                           String eventKey, NotificationType notificationType,
                           NotificationSeverity severity, String title, String body,
                           String navigationTarget, LocalDateTime createdAt) {
        this.user = user;
        this.vehicle = vehicle;
        this.reminderId = reminder == null ? null : reminder.getId();
        this.eventKey = eventKey;
        this.notificationType = notificationType;
        this.severity = severity;
        this.title = title;
        this.body = body;
        this.navigationTarget = navigationTarget;
        this.createdAt = createdAt;
    }

    public void markRead(LocalDateTime now) {
        if (readAt == null) readAt = now;
    }

    public void markPushAttempted(LocalDateTime now) {
        if (pushAttemptedAt == null) pushAttemptedAt = now;
    }

    public Long getId() { return id; }
    public User getUser() { return user; }
    public Vehicle getVehicle() { return vehicle; }
    public Long getReminderId() { return reminderId; }
    public String getEventKey() { return eventKey; }
    public NotificationType getNotificationType() { return notificationType; }
    public NotificationSeverity getSeverity() { return severity; }
    public String getTitle() { return title; }
    public String getBody() { return body; }
    public String getNavigationTarget() { return navigationTarget; }
    public LocalDateTime getReadAt() { return readAt; }
    public LocalDateTime getPushAttemptedAt() { return pushAttemptedAt; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
