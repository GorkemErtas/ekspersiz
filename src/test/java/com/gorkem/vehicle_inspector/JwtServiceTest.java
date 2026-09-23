package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.security.JwtService;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JwtServiceTest {

    private static final String VALID_SECRET =
            "0123456789abcdef0123456789abcdef";

    @Test
    void rejectsBlankSecret() {
        assertThrows(
                IllegalStateException.class,
                () -> new JwtService(" ", 86_400_000)
        );
    }

    @Test
    void rejectsShortSecret() {
        assertThrows(
                IllegalStateException.class,
                () -> new JwtService("too-short", 86_400_000)
        );
    }

    @Test
    void rejectsNonPositiveExpiration() {
        assertThrows(
                IllegalStateException.class,
                () -> new JwtService(VALID_SECRET, 0)
        );
    }

    @Test
    void acceptsValidConfiguration() {
        assertDoesNotThrow(
                () -> new JwtService(
                        VALID_SECRET,
                        86_400_000
                )
        );
    }
}