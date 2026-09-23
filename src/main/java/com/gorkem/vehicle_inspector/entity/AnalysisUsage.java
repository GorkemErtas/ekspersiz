package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "analysis_usages",
        indexes = {
                @Index(
                        name = "idx_analysis_usage_user_started",
                        columnList = "user_id, started_at"
                ),
                @Index(
                        name = "idx_analysis_usage_business_started",
                        columnList = "business_account_id, started_at"
                )
        }
)
public class AnalysisUsage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(
            name = "user_id",
            foreignKey = @ForeignKey(
                    name = "fk_analysis_usage_user"
            )
    )
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(
            name = "business_account_id",
            foreignKey = @ForeignKey(
                    name = "fk_analysis_usage_business"
            )
    )
    private BusinessAccount businessAccount;

    @Column(
            name = "started_at",
            nullable = false
    )
    private LocalDateTime startedAt;

    protected AnalysisUsage() {
    }

    private AnalysisUsage(
            User user,
            BusinessAccount businessAccount,
            LocalDateTime startedAt
    ) {
        this.user = user;
        this.businessAccount = businessAccount;
        this.startedAt = startedAt;
    }

    public static AnalysisUsage personal(
            User user,
            LocalDateTime startedAt
    ) {
        return new AnalysisUsage(
                user,
                null,
                startedAt
        );
    }

    public static AnalysisUsage business(
            BusinessAccount businessAccount,
            LocalDateTime startedAt
    ) {
        return new AnalysisUsage(
                null,
                businessAccount,
                startedAt
        );
    }

    public Long getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public BusinessAccount getBusinessAccount() {
        return businessAccount;
    }

    public LocalDateTime getStartedAt() {
        return startedAt;
    }
}