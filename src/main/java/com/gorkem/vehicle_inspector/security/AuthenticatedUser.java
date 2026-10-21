package com.gorkem.vehicle_inspector.security;

import com.gorkem.vehicle_inspector.entity.User;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.util.List;

/** Database identity and credential generation, never client-supplied authorities. */
public final class AuthenticatedUser extends org.springframework.security.core.userdetails.User {
    private final Long userId;
    private final long authVersion;

    public AuthenticatedUser(User user) {
        super(user.getEmail(), user.getPassword(), user.isEmailVerified(), true, true, true,
                List.of(new SimpleGrantedAuthority("APP_USER")));
        this.userId = user.getId();
        this.authVersion = user.getAuthVersion();
    }

    public Long getUserId() { return userId; }
    public long getAuthVersion() { return authVersion; }
}
