package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "pending_registrations",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_pending_registration_email",
                columnNames = "email"
        )
)
public class PendingRegistration {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "full_name", nullable = false, length = 100)
    private String fullName;

    @Column(nullable = false, length = 150)
    private String email;

    @Column(name = "password_hash", nullable = false, length = 100)
    private String passwordHash;

    @Column(name = "verification_code_hash", nullable = false, length = 100)
    private String verificationCodeHash;

    @Column(name = "verification_code_expires_at", nullable = false)
    private LocalDateTime verificationCodeExpiresAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    protected PendingRegistration() {
    }

    public PendingRegistration(
            String fullName,
            String email,
            String passwordHash,
            String verificationCodeHash,
            LocalDateTime now,
            LocalDateTime verificationCodeExpiresAt
    ) {
        this.fullName = fullName;
        this.email = email;
        this.passwordHash = passwordHash;
        this.verificationCodeHash = verificationCodeHash;
        this.createdAt = now;
        this.updatedAt = now;
        this.verificationCodeExpiresAt = verificationCodeExpiresAt;
    }

    public void replaceRegistration(
            String fullName,
            String passwordHash,
            String verificationCodeHash,
            LocalDateTime now,
            LocalDateTime verificationCodeExpiresAt
    ) {
        this.fullName = fullName;
        this.passwordHash = passwordHash;
        refreshCode(
                verificationCodeHash,
                now,
                verificationCodeExpiresAt
        );
    }

    public void refreshCode(
            String verificationCodeHash,
            LocalDateTime now,
            LocalDateTime verificationCodeExpiresAt
    ) {
        this.verificationCodeHash = verificationCodeHash;
        this.updatedAt = now;
        this.verificationCodeExpiresAt = verificationCodeExpiresAt;
    }

    public Long getId() {
        return id;
    }

    public String getFullName() {
        return fullName;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getVerificationCodeHash() {
        return verificationCodeHash;
    }

    public LocalDateTime getVerificationCodeExpiresAt() {
        return verificationCodeExpiresAt;
    }

    public boolean isVerificationCodeExpired(LocalDateTime now) {
        return !verificationCodeExpiresAt.isAfter(now);
    }
}
