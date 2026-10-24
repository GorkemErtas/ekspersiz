package com.gorkem.vehicle_inspector.client;

import com.gorkem.vehicle_inspector.dto.response.AiAnalysisResponse;
import com.gorkem.vehicle_inspector.dto.response.ImageQualityResponse;
import com.gorkem.vehicle_inspector.exception.DamageAnalysisUnavailableException;
import com.gorkem.vehicle_inspector.exception.AiServiceException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

/** Single-photo provider boundary. Disabled until explicit model release approval. */
@Component
public class AiAnalysisClient {
    private RestTemplate restTemplate;
    public AiAnalysisClient() {}
    @Autowired
    public AiAnalysisClient(RestTemplate restTemplate) { this.restTemplate = restTemplate; }
    @Value("${application.ai-service.base-url:http://localhost:8000}")
    private String baseUrl;
    @Value("${application.ai-service.api-key:}") private String serviceApiKey = "";
    @Value("${application.damage-analysis.enabled:false}") private boolean enabled;

    public void requireAvailable() {
        if (!enabled || restTemplate == null) throw new DamageAnalysisUnavailableException();
        try {
            var result = restTemplate.exchange(baseUrl + "/api/v1/vision/readiness", HttpMethod.GET,
                    new HttpEntity<>(headers()), Map.class).getBody();
            if (result == null || !"READY".equals(result.get("status"))
                    || !"hitl-v1".equals(result.get("schemaVersion"))) {
                throw new DamageAnalysisUnavailableException();
            }
        } catch (RestClientException exception) {
            throw new DamageAnalysisUnavailableException();
        }
    }

    public AiAnalysisResponse analyze(Path imagePath) {
        return analyzeSingleImage(imagePath, null);
    }

    public AiAnalysisResponse analyzeSingleImage(Path imagePath, String vehicleRegion) {
        var response = postImage(imagePath, vehicleRegion, "/api/v1/analyze", AiAnalysisResponse.class);
        com.gorkem.vehicle_inspector.service.HitlAnalysisValidator.validate(response);
        return response;
    }

    public AiAnalysisResponse analyze(Path imagePath, Path contextImagePath) {
        return analyzeSingleImage(imagePath, null);
    }

    public AiAnalysisResponse analyze(Path imagePath, Path contextImagePath, String vehicleRegion) {
        return analyzeSingleImage(imagePath, vehicleRegion);
    }

    public ImageQualityResponse validateImage(Path imagePath) {
        return validateImage(imagePath, "damage");
    }

    public ImageQualityResponse validateImage(Path imagePath, String purpose) {
        return postImage(imagePath, null, "/api/v1/validate-image", ImageQualityResponse.class);
    }

    private HttpHeaders headers() {
        var headers = new HttpHeaders();
        headers.set("X-AI-Service-Key", serviceApiKey);
        return headers;
    }

    private <T> T postImage(Path imagePath, String region, String endpoint, Class<T> responseType) {
        requireAvailable();
        if (imagePath == null || !Files.isRegularFile(imagePath)) {
            throw new AiServiceException("Analiz edilecek fotoğraf bulunamadı.");
        }
        var imageHeaders = new HttpHeaders();
        String name = imagePath.getFileName().toString().toLowerCase(java.util.Locale.ROOT);
        imageHeaders.setContentType(name.endsWith(".png") ? MediaType.IMAGE_PNG
                : name.endsWith(".webp") ? MediaType.parseMediaType("image/webp") : MediaType.IMAGE_JPEG);
        var body = new LinkedMultiValueMap<String, Object>();
        body.add("image", new HttpEntity<>(new FileSystemResource(imagePath), imageHeaders));
        if (region != null) body.add("vehicle_region", region);
        var requestHeaders = headers();
        requestHeaders.setContentType(MediaType.MULTIPART_FORM_DATA);
        try {
            var response = restTemplate.postForEntity(baseUrl + endpoint,
                    new HttpEntity<>(body, requestHeaders), responseType).getBody();
            if (response == null) throw new AiServiceException("AI servisi boş yanıt döndürdü.");
            return response;
        } catch (RestClientException exception) {
            throw new AiServiceException("Fotoğraf analizi tamamlanamadı; kredi tüketilmedi.", exception);
        }
    }
}
