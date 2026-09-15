package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "business_invitations",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_business_invitation_business_user",
                        columnNames = {
                                "business_account_id",
                                "user_id"
                        }
                )
        }
)
public class BusinessInvitation {

    private static final int EXPIRATION_MINUTES = 15;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(
            fetch = FetchType.LAZY,
            optional = false
    )
    @JoinColumn(
            name = "business_account_id",
            nullable = false
    )
    private BusinessAccount businessAccount;

    @ManyToOne(
            fetch = FetchType.LAZY,
            optional = false
    )
    @JoinColumn(
            name = "user_id",
            nullable = false
    )
    private User user;

    @Column(
            name = "code_hash",
            nullable = false
    )
    private String codeHash;

    @Column(
            name = "expires_at",
            nullable = false
    )
    private LocalDateTime expiresAt;

    @Column(
            name = "created_at",
            nullable = false,
            updatable = false
    )
    private LocalDateTime createdAt;

    protected BusinessInvitation() {
    }

    public BusinessInvitation(
            BusinessAccount businessAccount,
            User user,
            String codeHash
    ) {
        this.businessAccount = businessAccount;
        this.user = user;
        this.codeHash = codeHash;
        this.createdAt = LocalDateTime.now();
        this.expiresAt = createdAt.plusMinutes(
                EXPIRATION_MINUTES
        );
    }

    public Long getId() {
        return id;
    }

    public BusinessAccount getBusinessAccount() {
        return businessAccount;
    }

    public User getUser() {
        return user;
    }

    public String getCodeHash() {
        return codeHash;
    }

    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt);
    }

    public void refresh(String codeHash) {
        this.codeHash = codeHash;
        this.expiresAt = LocalDateTime.now()
                .plusMinutes(EXPIRATION_MINUTES);
    }
}