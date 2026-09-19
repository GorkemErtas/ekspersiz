package com.gorkem.vehicle_inspector.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.Collections;

@Service
public class GoogleAuthService {

    private final GoogleIdTokenVerifier verifier;

    public GoogleAuthService(
            @Value("${application.google.auth.client-id}")
            String clientId
    ) throws GeneralSecurityException, IOException {

        this.verifier = new GoogleIdTokenVerifier.Builder(
                GoogleNetHttpTransport.newTrustedTransport(),
                GsonFactory.getDefaultInstance()
        )
                .setAudience(Collections.singletonList(clientId))
                .build();
    }

    public GoogleIdToken.Payload verifyIdToken(String idToken) {
        try {
            GoogleIdToken token = verifier.verify(idToken);

            if (token == null) {
                throw new IllegalArgumentException(
                        "Google kimlik doğrulaması başarısız."
                );
            }

            GoogleIdToken.Payload payload = token.getPayload();

            String email = payload.getEmail();

            if (email == null || email.isBlank()) {
                throw new IllegalArgumentException(
                        "Google hesabından geçerli bir e-posta adresi alınamadı."
                );
            }

            if (!Boolean.TRUE.equals(payload.getEmailVerified())) {
                throw new IllegalArgumentException(
                        "Google hesabının e-posta adresi doğrulanmamış."
                );
            }

            return payload;

        } catch (GeneralSecurityException | IOException exception) {
            throw new IllegalArgumentException(
                    "Google kimlik doğrulaması başarısız.",
                    exception
            );
        }
    }
}