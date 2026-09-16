package com.gorkem.vehicle_inspector.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.exception.InvalidRewardCallbackException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

@Component
public class AdMobSsvVerifier {
    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final String keysUrl;
    private final HttpClient httpClient;
    private Map<Long, PublicKey> cachedKeys = Map.of();
    private Instant cacheExpiresAt = Instant.EPOCH;

    public AdMobSsvVerifier(ObjectMapper objectMapper, Clock clock,
                            @Value("${application.admob.ssv-keys-url:https://www.gstatic.com/admob/reward/verifier-keys.json}")
                            String keysUrl) {
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.keysUrl = keysUrl;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .build();
    }

    public void verify(String rawQuery) {
        try {
            int signatureStart = rawQuery.indexOf("&signature=");
            int keyStart = rawQuery.indexOf("&key_id=", signatureStart + 1);
            if (signatureStart < 0 || keyStart < 0) {
                throw new InvalidRewardCallbackException("AdMob ödül imzası eksik.");
            }
            byte[] content = rawQuery.substring(0, signatureStart)
                    .getBytes(java.nio.charset.StandardCharsets.UTF_8);
            String encodedSignature = rawQuery.substring(
                    signatureStart + "&signature=".length(), keyStart);
            long keyId = Long.parseLong(rawQuery.substring(keyStart + "&key_id=".length()));
            PublicKey publicKey = keys().get(keyId);
            if (publicKey == null) {
                refreshKeys();
                publicKey = cachedKeys.get(keyId);
            }
            if (publicKey == null) {
                throw new InvalidRewardCallbackException("AdMob imza anahtarı bulunamadı.");
            }
            Signature verifier = Signature.getInstance("SHA256withECDSA");
            verifier.initVerify(publicKey);
            verifier.update(content);
            if (!verifier.verify(Base64.getUrlDecoder().decode(pad(encodedSignature)))) {
                throw new InvalidRewardCallbackException("AdMob ödül imzası geçersiz.");
            }
        } catch (InvalidRewardCallbackException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new InvalidRewardCallbackException("AdMob ödül doğrulaması başarısız.", exception);
        }
    }

    private synchronized Map<Long, PublicKey> keys() throws Exception {
        if (cachedKeys.isEmpty() || !Instant.now(clock).isBefore(cacheExpiresAt)) {
            refreshKeys();
        }
        return cachedKeys;
    }

    private synchronized void refreshKeys() throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create(keysUrl))
                .timeout(Duration.ofSeconds(10)).GET().build();
        HttpResponse<String> response = httpClient.send(
                request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IllegalStateException("AdMob public keys returned " + response.statusCode());
        }
        JsonNode root = objectMapper.readTree(response.body());
        Map<Long, PublicKey> result = new HashMap<>();
        KeyFactory factory = KeyFactory.getInstance("EC");
        for (JsonNode key : root.path("keys")) {
            long keyId = key.path("keyId").asLong();
            byte[] bytes = Base64.getDecoder().decode(key.path("base64").asText());
            result.put(keyId, factory.generatePublic(new X509EncodedKeySpec(bytes)));
        }
        if (result.isEmpty()) throw new IllegalStateException("AdMob public key list is empty.");
        cachedKeys = Map.copyOf(result);
        cacheExpiresAt = Instant.now(clock).plus(Duration.ofHours(24));
    }

    private String pad(String value) {
        int padding = (4 - value.length() % 4) % 4;
        return value + "=".repeat(padding);
    }
}
