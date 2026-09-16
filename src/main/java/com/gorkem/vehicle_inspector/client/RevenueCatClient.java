package com.gorkem.vehicle_inspector.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.gorkem.vehicle_inspector.exception.BillingConfigurationException;
import com.gorkem.vehicle_inspector.exception.BillingProviderException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

@Component
public class RevenueCatClient {

    private final RestTemplate restTemplate;
    private final String baseUrl;
    private final String secretApiKey;

    public RevenueCatClient(
            RestTemplate restTemplate,
            @Value("${application.billing.revenuecat.base-url}")
            String baseUrl,
            @Value("${application.billing.revenuecat.secret-api-key:}")
            String secretApiKey
    ) {
        this.restTemplate = restTemplate;
        this.baseUrl = normalizeBaseUrl(baseUrl);
        this.secretApiKey = secretApiKey == null ? "" : secretApiKey.trim();
    }

    public RevenueCatCustomer getCustomer(String appUserId) {
        if (secretApiKey.isBlank()) {
            throw new BillingConfigurationException(
                    "Ödeme sistemi sunucuda henüz yapılandırılmadı."
            );
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(secretApiKey);

        try {
            ResponseEntity<JsonNode> response = restTemplate.exchange(
                    baseUrl + "/subscribers/{appUserId}",
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    JsonNode.class,
                    appUserId
            );

            JsonNode body = response.getBody();

            if (body == null || !body.path("subscriber").isObject()) {
                throw new BillingProviderException(
                        "Abonelik sağlayıcısından geçersiz yanıt alındı.",
                        null
                );
            }

            return parseCustomer(body.path("subscriber"));
        } catch (BillingProviderException exception) {
            throw exception;
        } catch (RestClientException exception) {
            throw new BillingProviderException(
                    "Abonelik bilgisi şu anda doğrulanamıyor.",
                    exception
            );
        }
    }

    private RevenueCatCustomer parseCustomer(JsonNode subscriber) {
        List<RevenueCatSubscription> subscriptions = new ArrayList<>();
        JsonNode subscriptionNodes = subscriber.path("subscriptions");

        if (subscriptionNodes.isObject()) {
            Iterator<Map.Entry<String, JsonNode>> fields =
                    subscriptionNodes.fields();

            while (fields.hasNext()) {
                Map.Entry<String, JsonNode> field = fields.next();
                JsonNode value = field.getValue();

                subscriptions.add(new RevenueCatSubscription(
                        field.getKey(),
                        parseInstant(value.path("purchase_date")),
                        parseInstant(value.path("expires_date")),
                        parseInstant(value.path("grace_period_expires_date")),
                        !value.hasNonNull("unsubscribe_detected_at")
                                || value.hasNonNull("auto_resume_date"),
                        value.hasNonNull("billing_issues_detected_at"),
                        value.hasNonNull("refunded_at"),
                        value.path("is_sandbox").asBoolean(false),
                        textOrNull(value.path("store"))
                ));
            }
        }

        return new RevenueCatCustomer(
                List.copyOf(subscriptions),
                textOrNull(subscriber.path("management_url"))
        );
    }

    private Instant parseInstant(JsonNode node) {
        String value = textOrNull(node);

        if (value == null) {
            return null;
        }

        try {
            return Instant.parse(value);
        } catch (DateTimeParseException exception) {
            throw new BillingProviderException(
                    "Abonelik sağlayıcısı geçersiz tarih bilgisi döndürdü.",
                    exception
            );
        }
    }

    private String textOrNull(JsonNode node) {
        if (node == null || node.isMissingNode() || node.isNull()) {
            return null;
        }

        String value = node.asText();
        return value.isBlank() ? null : value;
    }

    private String normalizeBaseUrl(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(
                    "RevenueCat servis adresi boş olamaz."
            );
        }

        String normalized = value.trim();

        while (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        return normalized;
    }
}
