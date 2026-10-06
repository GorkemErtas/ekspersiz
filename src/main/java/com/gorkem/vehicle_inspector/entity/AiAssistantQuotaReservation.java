package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "ai_assistant_quota_reservations")
public class AiAssistantQuotaReservation {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
    @Column(name = "usage_date", nullable = false) private LocalDate usageDate;
    @Column(nullable = false) private String status;
    @Column(name = "expires_at", nullable = false) private LocalDateTime expiresAt;
    @Column(name = "created_at", nullable = false) private LocalDateTime createdAt;
    @Column(name = "completed_at") private LocalDateTime completedAt;
    @Column(name = "released_at") private LocalDateTime releasedAt;

    protected AiAssistantQuotaReservation() {}

    public AiAssistantQuotaReservation(UUID id, User user, LocalDate usageDate,
            LocalDateTime now, LocalDateTime expiresAt) {
        this.id=id; this.user=user; this.usageDate=usageDate;
        this.status="RESERVED"; this.createdAt=now; this.expiresAt=expiresAt;
    }

    public void complete(LocalDateTime now) {
        if (!isActive(now)) throw new IllegalStateException("AI quota reservation is not active.");
        status="COMPLETED"; completedAt=now;
    }

    public void release(LocalDateTime now) {
        if ("RESERVED".equals(status)) {
            status="RELEASED"; releasedAt=now;
        }
    }

    public boolean isActive(LocalDateTime now) {
        return "RESERVED".equals(status) && expiresAt.isAfter(now);
    }

    public UUID getId() { return id; }
}
