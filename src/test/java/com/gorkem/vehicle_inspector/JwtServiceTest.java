package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.security.JwtService;
import com.gorkem.vehicle_inspector.security.AuthenticatedUser;
import com.gorkem.vehicle_inspector.entity.User;
import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import org.springframework.test.util.ReflectionTestUtils;
import java.time.Instant;
import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JwtServiceTest {

    private User user(long id) {
        User user = new User("Owner", "owner@example.com", "password-hash");
        ReflectionTestUtils.setField(user, "id", id);
        user.markEmailVerified();
        return user;
    }

    @Test
    void tokenCannotAccessRecreatedAccountWithSameEmail() {
        JwtService service = new JwtService(VALID_SECRET, 86_400_000);
        String token = service.generateToken(user(1));
        assertTrue(service.isTokenValid(token, new AuthenticatedUser(user(1))));
        assertFalse(service.isTokenValid(token, new AuthenticatedUser(user(2))));
    }

    @Test
    void credentialChangeRevokesOldTokensButNewTokenWorks() {
        JwtService service = new JwtService(VALID_SECRET, 86_400_000);
        User user = user(1);
        String token = service.generateToken(user);
        user.setPassword("new-password-hash");
        assertFalse(service.isTokenValid(token, new AuthenticatedUser(user)));
        assertTrue(service.isTokenValid(service.generateToken(user), new AuthenticatedUser(user)));
    }

    @Test
    void legacyTokensRemainValidOnlyUntilCredentialsChange() {
        JwtService service = new JwtService(VALID_SECRET, 86_400_000);
        String legacy = JWT.create().withIssuer("vehicle-inspector-api")
                .withSubject("owner@example.com").withClaim("userId", 1L)
                .withIssuedAt(Instant.now()).withExpiresAt(Instant.now().plusSeconds(3600))
                .sign(Algorithm.HMAC256(VALID_SECRET));
        User user = user(1);
        assertTrue(service.isTokenValid(legacy, new AuthenticatedUser(user)));
        user.setPassword("changed");
        assertFalse(service.isTokenValid(legacy, new AuthenticatedUser(user)));
    }

    @Test
    void rejectsMissingExpirationWrongIssuerSignatureAndDisabledUser() {
        JwtService service = new JwtService(VALID_SECRET, 86_400_000);
        var principal = new AuthenticatedUser(user(1));
        for (String invalid : new String[] {
                JWT.create().withIssuer("vehicle-inspector-api").withSubject(principal.getUsername())
                        .withClaim("userId", 1L).withIssuedAt(Instant.now()).sign(Algorithm.HMAC256(VALID_SECRET)),
                JWT.create().withIssuer("other").withSubject(principal.getUsername())
                        .withClaim("userId", 1L).withIssuedAt(Instant.now())
                        .withExpiresAt(Instant.now().plusSeconds(3600)).sign(Algorithm.HMAC256(VALID_SECRET)),
                new JwtService(VALID_SECRET + "other", 3600000).generateToken(user(1)),
                "not-a-jwt"
        }) assertFalse(service.isTokenValid(invalid, principal));
        User disabled = new User("Owner", "owner@example.com", "hash");
        ReflectionTestUtils.setField(disabled, "id", 1L);
        assertFalse(service.isTokenValid(service.generateToken(disabled), new AuthenticatedUser(disabled)));
    }

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
