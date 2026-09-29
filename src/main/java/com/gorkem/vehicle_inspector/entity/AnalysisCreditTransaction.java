package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(
        name = "analysis_credit_transactions",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_analysis_credit_external_transaction",
                        columnNames = "external_transaction_id"
                )
        },
        indexes = {
                @Index(
                        name = "idx_analysis_credit_user_created",
                        columnList = "user_id, created_at"
                )
        }
)
public class AnalysisCreditTransaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false,
            foreignKey = @ForeignKey(name = "fk_analysis_credit_user"))
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AnalysisCreditTransactionType type;

    @Column(nullable = false)
    private int amount;

    @Column(name = "product_id", length = 120)
    private String productId;

    @Column(name = "external_transaction_id", length = 200)
    private String externalTransactionId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "inspection_id",
            foreignKey = @ForeignKey(name = "fk_analysis_credit_inspection"))
    private DamageInspection inspection;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    protected AnalysisCreditTransaction() {}

    private AnalysisCreditTransaction(
            User user,
            AnalysisCreditTransactionType type,
            int amount,
            String productId,
            String externalTransactionId,
            DamageInspection inspection,
            LocalDateTime createdAt
    ) {
        this.user = user;
        this.type = type;
        this.amount = amount;
        this.productId = productId;
        this.externalTransactionId = externalTransactionId;
        this.inspection = inspection;
        this.createdAt = createdAt;
    }

    public static AnalysisCreditTransaction purchase(
            User user, int amount, String productId,
            String transactionId, LocalDateTime createdAt
    ) {
        return new AnalysisCreditTransaction(
                user, AnalysisCreditTransactionType.PURCHASE,
                amount, productId, transactionId, null, createdAt
        );
    }

    public static AnalysisCreditTransaction consume(
            User user, DamageInspection inspection, LocalDateTime createdAt
    ) {
        return new AnalysisCreditTransaction(
                user, AnalysisCreditTransactionType.CONSUME,
                -1, null, null, inspection, createdAt
        );
    }

    public int getAmount() {
        return amount;
    }

    public AnalysisCreditTransactionType getType() {
        return type;
    }

    public String getExternalTransactionId() {
        return externalTransactionId;
    }
}
