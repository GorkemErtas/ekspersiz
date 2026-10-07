package com.gorkem.vehicle_inspector.client;

import com.gorkem.vehicle_inspector.dto.response.AiAssistantPlanResponse;
import com.gorkem.vehicle_inspector.exception.AiServiceException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import java.util.Map;

@Component
public class AiAssistantClient {
    private final RestTemplate restTemplate;
    private final String baseUrl;

    public AiAssistantClient(RestTemplate restTemplate, @Value("${application.ai-service.base-url}") String baseUrl) {
        this.restTemplate = restTemplate;
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
    }

    public AiAssistantPlanResponse plan(String question) {
        try {
            var headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            var request = new HttpEntity<>(Map.of("question", question), headers);
            var response = restTemplate.postForEntity(baseUrl + "/api/v1/assistant/plan", request, AiAssistantPlanResponse.class);
            if (response.getBody() == null) throw new AiServiceException("AI Asistan planlama servisi boş cevap döndürdü.");
            return response.getBody();
        } catch (RestClientException ex) {
            throw new AiServiceException("AI Asistan planlama servisine ulaşılamadı.", ex);
        }
    }
}
