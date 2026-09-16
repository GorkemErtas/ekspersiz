package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.exception.InvalidBillingWebhookException;
import com.gorkem.vehicle_inspector.service.billing.RevenueCatWebhookVerifier;
import org.junit.jupiter.api.Test;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HexFormat;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class RevenueCatWebhookVerifierTest {

    private static final long TIMESTAMP = 1_789_549_200L;
    private static final String BODY = "{\"event\":{\"id\":\"event-1\"}}";

    @Test
    void shouldVerifyAuthorizationAndHmacSignature() throws Exception {
        RevenueCatWebhookVerifier verifier = verifier();
        String signature = sign(TIMESTAMP + "." + BODY, "signing-secret");

        assertDoesNotThrow(() -> verifier.verify(
                "Bearer webhook-secret",
                "t=" + TIMESTAMP + ",v1=" + signature,
                BODY
        ));
    }

    @Test
    void shouldRejectChangedPayload() throws Exception {
        RevenueCatWebhookVerifier verifier = verifier();
        String signature = sign(TIMESTAMP + "." + BODY, "signing-secret");

        assertThrows(InvalidBillingWebhookException.class, () -> verifier.verify(
                "Bearer webhook-secret",
                "t=" + TIMESTAMP + ",v1=" + signature,
                BODY + " "
        ));
    }

    @Test
    void shouldRejectWrongAuthorization() {
        assertThrows(InvalidBillingWebhookException.class, () -> verifier().verify(
                "Bearer wrong",
                null,
                BODY
        ));
    }

    private RevenueCatWebhookVerifier verifier() {
        return new RevenueCatWebhookVerifier(
                "Bearer webhook-secret",
                "signing-secret",
                Clock.fixed(Instant.ofEpochSecond(TIMESTAMP), ZoneOffset.UTC)
        );
    }

    private String sign(String value, String secret) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(
                secret.getBytes(StandardCharsets.UTF_8),
                "HmacSHA256"
        ));
        return HexFormat.of().formatHex(
                mac.doFinal(value.getBytes(StandardCharsets.UTF_8))
        );
    }
}
