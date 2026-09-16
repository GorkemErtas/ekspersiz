package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "device_tokens", uniqueConstraints = @UniqueConstraint(
        name = "uk_device_token", columnNames = "token"))
public class DeviceToken {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 512)
    private String token;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private DevicePlatform platform;

    @Column(nullable = false)
    private boolean active;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    protected DeviceToken() {
    }

    public DeviceToken(User user, String token, DevicePlatform platform, LocalDateTime now) {
        update(user, platform, now);
        this.token = token;
    }

    public void update(User user, DevicePlatform platform, LocalDateTime now) {
        this.user = user;
        this.platform = platform;
        this.active = true;
        this.updatedAt = now;
    }

    public void deactivate(LocalDateTime now) {
        this.active = false;
        this.updatedAt = now;
    }

    public Long getId() { return id; }
    public User getUser() { return user; }
    public String getToken() { return token; }
    public DevicePlatform getPlatform() { return platform; }
    public boolean isActive() { return active; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
}
