package com.gorkem.vehicle_inspector.client;

import com.gorkem.vehicle_inspector.dto.response.AiAnalysisResponse;
import com.gorkem.vehicle_inspector.dto.response.ImageQualityResponse;
import com.gorkem.vehicle_inspector.exception.AiServiceException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.nio.file.Files;
import java.nio.file.Path;

@Component
public class AiAnalysisClient {

    private final RestTemplate restTemplate;
    private final String aiServiceBaseUrl;

    public AiAnalysisClient(
            RestTemplate restTemplate,
            @Value("${application.ai-service.base-url}")
            String aiServiceBaseUrl
    ) {
        this.restTemplate = restTemplate;
        this.aiServiceBaseUrl =
                normalizeBaseUrl(aiServiceBaseUrl);
    }

    public AiAnalysisResponse analyze(
            Path imagePath
    ) {
        return postImage(
                imagePath,
                "/api/v1/analyze",
                AiAnalysisResponse.class
        );
    }

    public ImageQualityResponse validateImage(
            Path imagePath
    ) {
        return postImage(
                imagePath,
                "/api/v1/validate-image",
                ImageQualityResponse.class
        );
    }

    private <T> T postImage(
            Path imagePath,
            String endpoint,
            Class<T> responseType
    ) {
        if (imagePath == null
                || !Files.exists(imagePath)
                || !Files.isRegularFile(imagePath)) {
            throw new AiServiceException(
                    "Analiz edilecek fotoğraf bulunamadı."
            );
        }

        FileSystemResource imageResource =
                new FileSystemResource(imagePath);

        HttpHeaders imageHeaders =
                new HttpHeaders();

        String detectedContentType;

        try {
            detectedContentType =
                    Files.probeContentType(imagePath);
        } catch (Exception exception) {
            detectedContentType = null;
        }

        MediaType imageMediaType;

        if ("image/png".equals(detectedContentType)) {
            imageMediaType = MediaType.IMAGE_PNG;

        } else if ("image/webp".equals(detectedContentType)) {
            imageMediaType =
                    MediaType.parseMediaType("image/webp");

        } else {
            imageMediaType = MediaType.IMAGE_JPEG;
        }

        imageHeaders.setContentType(
                imageMediaType
        );

        imageHeaders.setContentDisposition(
                ContentDisposition
                        .formData()
                        .name("image")
                        .filename(
                                imagePath
                                        .getFileName()
                                        .toString()
                        )
                        .build()
        );

        HttpEntity<FileSystemResource> imagePart =
                new HttpEntity<>(
                        imageResource,
                        imageHeaders
                );

        MultiValueMap<String, Object> multipartBody =
                new LinkedMultiValueMap<>();

        multipartBody.add(
                "image",
                imagePart
        );

        HttpHeaders requestHeaders =
                new HttpHeaders();

        requestHeaders.setContentType(
                MediaType.MULTIPART_FORM_DATA
        );

        requestHeaders.setAccept(
                java.util.List.of(
                        MediaType.APPLICATION_JSON
                )
        );

        HttpEntity<MultiValueMap<String, Object>> request =
                new HttpEntity<>(
                        multipartBody,
                        requestHeaders
                );

        try {
            ResponseEntity<T> response =
                    restTemplate.postForEntity(
                            aiServiceBaseUrl
                                    + endpoint,
                            request,
                            responseType
                    );

            T responseBody =
                    response.getBody();

            if (responseBody == null) {
                throw new AiServiceException(
                        "AI servisi boş cevap döndürdü."
                );
            }

            return responseBody;

        } catch (ResourceAccessException exception) {
            throw new AiServiceException(
                    "AI analiz servisi zaman aşımına uğradı "
                            + "veya servise bağlanılamadı.",
                    exception
            );

        } catch (HttpStatusCodeException exception) {
            throw new AiServiceException(
                    "AI analiz servisi hata döndürdü. HTTP "
                            + exception
                            .getStatusCode()
                            .value(),
                    exception
            );

        } catch (RestClientException exception) {
            throw new AiServiceException(
                    "AI analiz servisi ile iletişim "
                            + "sırasında hata oluştu.",
                    exception
            );
        }
    }

    private static String normalizeBaseUrl(
            String baseUrl
    ) {
        if (baseUrl == null
                || baseUrl.isBlank()) {
            throw new IllegalArgumentException(
                    "AI servis adresi boş olamaz."
            );
        }

        String normalized =
                baseUrl.trim();

        while (normalized.endsWith("/")) {
            normalized =
                    normalized.substring(
                            0,
                            normalized.length() - 1
                    );
        }

        return normalized;
    }
}
