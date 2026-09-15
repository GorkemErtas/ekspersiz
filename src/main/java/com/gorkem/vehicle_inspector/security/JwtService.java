package com.gorkem.vehicle_inspector.security;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.gorkem.vehicle_inspector.entity.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
public class JwtService {

    private static final String ISSUER = "vehicle-inspector-api";

    private final Algorithm algorithm;
    private final JWTVerifier verifier;
    private final long expiration;

    public JwtService(
            @Value("${application.security.jwt.secret}")
            String secret,
            @Value("${application.security.jwt.expiration}")
            long expiration
    ) {
        this.algorithm = Algorithm.HMAC256(secret);
        this.expiration = expiration;

        this.verifier = JWT.require(algorithm)
                .withIssuer(ISSUER)
                .build();
    }

    public String generateToken(User user) {
        Instant now = Instant.now();
        Instant expiresAt = now.plusMillis(expiration);

        return JWT.create()
                .withIssuer(ISSUER)
                .withSubject(user.getEmail())
                .withClaim("userId", user.getId())
                .withIssuedAt(now)
                .withExpiresAt(expiresAt)
                .sign(algorithm);
    }

    public String extractEmail(String token) {
        try {
            return verifier.verify(token).getSubject();
        } catch (JWTVerificationException exception) {
            return null;
        }
    }

    public boolean isTokenValid(String token, String email) {
        try {
            String tokenEmail = verifier.verify(token).getSubject();

            return tokenEmail != null
                    && tokenEmail.equalsIgnoreCase(email);
        } catch (JWTVerificationException exception) {
            return false;
        }
    }

    public long getExpiration() {
        return expiration;
    }
}