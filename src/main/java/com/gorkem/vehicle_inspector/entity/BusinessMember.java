package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "business_members",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_business_member_user",
                        columnNames = "user_id"
                )
        }
)
public class BusinessMember {

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

    @OneToOne(
            fetch = FetchType.LAZY,
            optional = false
    )
    @JoinColumn(
            name = "user_id",
            nullable = false
    )
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(
            nullable = false,
            length = 20
    )
    private BusinessRole role;

    @Column(
            name = "joined_at",
            nullable = false,
            updatable = false
    )
    private LocalDateTime joinedAt;

    protected BusinessMember() {
    }

    public BusinessMember(
            BusinessAccount businessAccount,
            User user,
            BusinessRole role
    ) {
        this.businessAccount = businessAccount;
        this.user = user;
        this.role = role;
        this.joinedAt = LocalDateTime.now();
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

    public BusinessRole getRole() {
        return role;
    }

    public LocalDateTime getJoinedAt() {
        return joinedAt;
    }

    public void setRole(BusinessRole role) {
        this.role = role;
    }
}