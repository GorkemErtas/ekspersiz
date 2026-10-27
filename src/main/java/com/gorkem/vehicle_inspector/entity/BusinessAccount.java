package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "business_accounts")
public class BusinessAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(
            name = "company_name",
            nullable = false,
            length = 150
    )
    private String companyName;

    // Immutable source boundary: an existing real company can never become a test company.
    @Column(nullable = false, updatable = false)
    private boolean sandbox;

    @Column(
            name = "created_at",
            nullable = false,
            updatable = false
    )
    private LocalDateTime createdAt;

    protected BusinessAccount() {
    }

    public BusinessAccount(String companyName) {
        this(companyName, false);
    }

    public BusinessAccount(String companyName, boolean sandbox) {
        this.companyName = companyName;
        this.sandbox = sandbox;
        this.createdAt = LocalDateTime.now();
    }

    public boolean isSandbox() { return sandbox; }

    public Long getId() {
        return id;
    }

    public String getCompanyName() {
        return companyName;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCompanyName(String companyName) {
        this.companyName = companyName;
    }
}
