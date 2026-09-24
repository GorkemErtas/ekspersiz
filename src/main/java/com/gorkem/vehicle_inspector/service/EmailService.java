package com.gorkem.vehicle_inspector.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

@Service
public class EmailService {

    private final RestClient restClient;
    private final String apiKey;
    private final String senderEmail;
    private final String senderName;

    public EmailService(
            RestClient.Builder restClientBuilder,
            @Value("${application.email.brevo.api-key}") String apiKey,
            @Value("${application.email.sender-email}") String senderEmail,
            @Value("${application.email.sender-name}") String senderName
    ) {
        this.restClient = restClientBuilder
                .baseUrl("https://api.brevo.com/v3")
                .build();

        this.apiKey = apiKey;
        this.senderEmail = senderEmail;
        this.senderName = senderName;
    }

    public void send(String recipientEmail, String subject, String content) {
        Map<String, Object> request = Map.of(
                "sender", Map.of(
                        "name", senderName,
                        "email", senderEmail
                ),
                "to", List.of(
                        Map.of("email", recipientEmail)
                ),
                "subject", subject,
                "textContent", content
        );

        restClient.post()
                .uri("/smtp/email")
                .header("api-key", apiKey)
                .header(HttpHeaders.ACCEPT, MediaType.APPLICATION_JSON_VALUE)
                .contentType(MediaType.APPLICATION_JSON)
                .body(request)
                .retrieve()
                .toBodilessEntity();
    }
}
