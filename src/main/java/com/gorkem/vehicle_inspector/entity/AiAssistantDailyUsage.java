package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "ai_assistant_daily_usage", uniqueConstraints = @UniqueConstraint(name = "uk_ai_assistant_daily_usage", columnNames = {"user_id", "usage_date"}))
public class AiAssistantDailyUsage {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id", nullable = false) private User user;
    @Column(name = "usage_date", nullable = false) private LocalDate usageDate;
    @Column(name = "successful_questions", nullable = false) private int successfulQuestions;
    @Column(name = "out_of_scope_attempts", nullable = false) private int outOfScopeAttempts;
    @Column(name = "created_at", nullable = false) private LocalDateTime createdAt;
    @Column(name = "updated_at", nullable = false) private LocalDateTime updatedAt;

    protected AiAssistantDailyUsage() {}
    public AiAssistantDailyUsage(User user, LocalDate date, LocalDateTime now) { this.user=user; this.usageDate=date; this.createdAt=now; this.updatedAt=now; }
    public void recordSuccess(LocalDateTime now) { successfulQuestions++; updatedAt=now; }
    public void recordOutOfScope(LocalDateTime now) { outOfScopeAttempts++; updatedAt=now; }
    public int getSuccessfulQuestions() { return successfulQuestions; }
    public int getOutOfScopeAttempts() { return outOfScopeAttempts; }
}
