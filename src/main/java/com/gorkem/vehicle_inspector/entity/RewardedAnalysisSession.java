package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "rewarded_analysis_sessions", uniqueConstraints = {
        @UniqueConstraint(name = "uk_reward_user_month", columnNames = {"user_id", "month_start"}),
        @UniqueConstraint(name = "uk_reward_token", columnNames = "token"),
        @UniqueConstraint(name = "uk_reward_transaction", columnNames = "transaction_id")
})
public class RewardedAnalysisSession {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "month_start", nullable = false)
    private LocalDate monthStart;

    @Column(nullable = false, length = 36)
    private String token;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "transaction_id", length = 128)
    private String transactionId;

    @Column(name = "claimed_at")
    private LocalDateTime claimedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    protected RewardedAnalysisSession() {
    }

    public RewardedAnalysisSession(User user, LocalDate monthStart, String token,
                                   LocalDateTime expiresAt, LocalDateTime now) {
        this.user = user;
        this.monthStart = monthStart;
        this.createdAt = now;
        rotate(token, expiresAt);
    }

    public void rotate(String token, LocalDateTime expiresAt) {
        if (claimedAt != null) throw new IllegalStateException("Ödüllü analiz hakkı zaten kazanıldı.");
        this.token = token;
        this.expiresAt = expiresAt;
    }

    public void claim(String transactionId, LocalDateTime now) {
        this.transactionId = transactionId;
        this.claimedAt = now;
    }

    public Long getId() { return id; }
    public User getUser() { return user; }
    public LocalDate getMonthStart() { return monthStart; }
    public String getToken() { return token; }
    public LocalDateTime getExpiresAt() { return expiresAt; }
    public String getTransactionId() { return transactionId; }
    public LocalDateTime getClaimedAt() { return claimedAt; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
