package com.gorkem.vehicle_inspector.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;

@Service
public class VerificationCodeService {

    private static final int CODE_BOUND = 1_000_000;
    private static final int CODE_LENGTH = 6;

    private final PasswordEncoder passwordEncoder;
    private final SecureRandom secureRandom = new SecureRandom();

    public VerificationCodeService(
            PasswordEncoder passwordEncoder
    ) {
        this.passwordEncoder = passwordEncoder;
    }

    public String generate() {
        int value = secureRandom.nextInt(CODE_BOUND);

        return String.format(
                "%0" + CODE_LENGTH + "d",
                value
        );
    }

    public String hash(String code) {
        return passwordEncoder.encode(code);
    }

    public boolean matches(
            String rawCode,
            String hashedCode
    ) {
        return passwordEncoder.matches(
                rawCode,
                hashedCode
        );
    }
}