package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "ai_assistant_access")
public class AiAssistantAccess {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private AiAssistantAccessStatus status = AiAssistantAccessStatus.INACTIVE;
    @Column(name = "trial_started_at") private LocalDateTime trialStartedAt;
    @Column(name = "trial_expires_at") private LocalDateTime trialExpiresAt;
    @Column(name = "subscription_started_at") private LocalDateTime subscriptionStartedAt;
    @Column(name = "subscription_expires_at") private LocalDateTime subscriptionExpiresAt;
    @Column(name = "locked_until") private LocalDateTime lockedUntil;
    @Column(name = "created_at", nullable = false) private LocalDateTime createdAt;
    @Column(name = "updated_at", nullable = false) private LocalDateTime updatedAt;

    protected AiAssistantAccess() {}
    public AiAssistantAccess(User user, LocalDateTime now) {
        this.user = user; this.createdAt = now; this.updatedAt = now;
    }
    public void startTrial(LocalDateTime now) {
        if (trialStartedAt != null) throw new IllegalStateException("AI Asistan deneme hakkı daha önce kullanılmış.");
        trialStartedAt = now; trialExpiresAt = now.plusDays(30); status = AiAssistantAccessStatus.TRIAL; updatedAt = now;
    }
    public void activateSubscription(LocalDateTime startedAt, LocalDateTime expiresAt) {
        subscriptionStartedAt = startedAt; subscriptionExpiresAt = expiresAt; status = AiAssistantAccessStatus.ACTIVE; lockedUntil = null; updatedAt = startedAt;
    }
    public void lockUntil(LocalDateTime until, LocalDateTime now) { lockedUntil = until; status = AiAssistantAccessStatus.LOCKED; updatedAt = now; }
    public void refresh(LocalDateTime now) {
        if (status == AiAssistantAccessStatus.LOCKED && lockedUntil != null && !lockedUntil.isAfter(now)) {
            lockedUntil = null;
            status = subscriptionExpiresAt == null && subscriptionStartedAt != null ? AiAssistantAccessStatus.ACTIVE
                    : subscriptionExpiresAt != null && subscriptionExpiresAt.isAfter(now) ? AiAssistantAccessStatus.ACTIVE
                    : trialExpiresAt != null && trialExpiresAt.isAfter(now) ? AiAssistantAccessStatus.TRIAL : AiAssistantAccessStatus.EXPIRED;
        }
        if (status == AiAssistantAccessStatus.TRIAL && trialExpiresAt != null && !trialExpiresAt.isAfter(now)) status = AiAssistantAccessStatus.EXPIRED;
        if (status == AiAssistantAccessStatus.ACTIVE && subscriptionExpiresAt != null && !subscriptionExpiresAt.isAfter(now)) status = AiAssistantAccessStatus.EXPIRED;
        updatedAt = now;
    }
    public boolean canAsk(LocalDateTime now) { refresh(now); return status == AiAssistantAccessStatus.TRIAL || status == AiAssistantAccessStatus.ACTIVE; }
    public AiAssistantAccessStatus getStatus() { return status; }
    public LocalDateTime getTrialStartedAt() { return trialStartedAt; }
    public LocalDateTime getTrialExpiresAt() { return trialExpiresAt; }
    public LocalDateTime getSubscriptionExpiresAt() { return subscriptionExpiresAt; }
    public LocalDateTime getLockedUntil() { return lockedUntil; }
}
