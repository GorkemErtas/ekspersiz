package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.DeviceTokenRequest;
import com.gorkem.vehicle_inspector.entity.DeviceToken;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.DeviceTokenRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;

@Service
public class DeviceTokenService {
    private final DeviceTokenRepository tokens;
    private final BusinessContextService businessContext;
    private final Clock clock;

    public DeviceTokenService(DeviceTokenRepository tokens,
                              BusinessContextService businessContext, Clock clock) {
        this.tokens = tokens;
        this.businessContext = businessContext;
        this.clock = clock;
    }

    @Transactional
    public void register(DeviceTokenRequest request, String email) {
        User user = businessContext.requireUser(email);
        String tokenValue = request.token().trim();
        LocalDateTime now = LocalDateTime.now(clock);
        DeviceToken token = tokens.findByToken(tokenValue)
                .orElseGet(() -> new DeviceToken(user, tokenValue, request.platform(), now));
        token.update(user, request.platform(), now);
        tokens.save(token);
    }

    @Transactional
    public void unregister(String tokenValue, String email) {
        User user = businessContext.requireUser(email);
        tokens.findByToken(tokenValue.trim())
                .filter(token -> token.getUser().getId().equals(user.getId()))
                .ifPresent(token -> {
                    token.deactivate(LocalDateTime.now(clock));
                    tokens.save(token);
                });
    }
}
