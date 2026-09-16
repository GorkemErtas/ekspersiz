package com.gorkem.vehicle_inspector.service.billing;

import com.gorkem.vehicle_inspector.exception.BillingConfigurationException;
import com.gorkem.vehicle_inspector.exception.InvalidBillingWebhookException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;

@Component
public class RevenueCatWebhookVerifier {

    private static final Duration SIGNATURE_TOLERANCE = Duration.ofMinutes(5);

    private final String expectedAuthorization;
    private final String signingSecret;
    private final Clock clock;

    public RevenueCatWebhookVerifier(
            @Value("${application.billing.revenuecat.webhook-authorization:}")
            String expectedAuthorization,
            @Value("${application.billing.revenuecat.webhook-signing-secret:}")
            String signingSecret,
            Clock clock
    ) {
        this.expectedAuthorization = trim(expectedAuthorization);
        this.signingSecret = trim(signingSecret);
        this.clock = clock;
    }

    public void verify(
            String authorization,
            String signatureHeader,
            String rawBody
    ) {
        if (expectedAuthorization.isBlank()) {
            throw new BillingConfigurationException(
                    "RevenueCat webhook doğrulaması sunucuda yapılandırılmadı."
            );
        }

        if (!constantTimeEquals(expectedAuthorization, trim(authorization))) {
            throw new InvalidBillingWebhookException(
                    "Geçersiz ödeme webhook yetkilendirmesi."
            );
        }

        if (signingSecret.isBlank()) {
            return;
        }

        SignatureParts parts = parseSignature(signatureHeader);
        Instant signedAt = Instant.ofEpochSecond(parts.timestamp());

        if (Duration.between(signedAt, clock.instant()).abs()
                .compareTo(SIGNATURE_TOLERANCE) > 0) {
            throw new InvalidBillingWebhookException(
                    "Ödeme webhook imzasının süresi geçmiş."
            );
        }

        String expectedSignature = sign(
                parts.timestamp() + "." + rawBody
        );

        if (!constantTimeEquals(expectedSignature, parts.signature())) {
            throw new InvalidBillingWebhookException(
                    "Geçersiz ödeme webhook imzası."
            );
        }
    }

    private SignatureParts parseSignature(String header) {
        String timestamp = null;
        String signature = null;

        for (String part : trim(header).split(",")) {
            String[] values = part.trim().split("=", 2);

            if (values.length != 2) {
                continue;
            }

            if (values[0].equals("t")) {
                timestamp = values[1];
            } else if (values[0].equals("v1")) {
                signature = values[1];
            }
        }

        try {
            if (timestamp == null || signature == null) {
                throw new NumberFormatException();
            }

            return new SignatureParts(
                    Long.parseLong(timestamp),
                    signature.toLowerCase()
            );
        } catch (NumberFormatException exception) {
            throw new InvalidBillingWebhookException(
                    "Ödeme webhook imza başlığı geçersiz."
            );
        }
    }

    private String sign(String message) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(
                    signingSecret.getBytes(StandardCharsets.UTF_8),
                    "HmacSHA256"
            ));

            return HexFormat.of().formatHex(
                    mac.doFinal(message.getBytes(StandardCharsets.UTF_8))
            );
        } catch (Exception exception) {
            throw new IllegalStateException(
                    "Webhook imzası doğrulanamadı.",
                    exception
            );
        }
    }

    private boolean constantTimeEquals(String first, String second) {
        return MessageDigest.isEqual(
                first.getBytes(StandardCharsets.UTF_8),
                second.getBytes(StandardCharsets.UTF_8)
        );
    }

    private static String trim(String value) {
        return value == null ? "" : value.trim();
    }

    private record SignatureParts(long timestamp, String signature) {
    }
}
