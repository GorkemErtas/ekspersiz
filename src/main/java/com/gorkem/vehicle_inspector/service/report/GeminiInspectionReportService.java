package com.gorkem.vehicle_inspector.service.report;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.genai.Client;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.Schema;
import com.google.genai.types.Type;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.LlmInspectionReportResult;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@Service
public class GeminiInspectionReportService {

    private final Client geminiClient;
    private final ObjectMapper objectMapper;
    private final String model;

    public GeminiInspectionReportService(
            Client geminiClient,
            ObjectMapper objectMapper,
            @Value("${application.gemini.model}")
            String model
    ) {
        this.geminiClient = geminiClient;
        this.objectMapper = objectMapper;
        this.model = model;
    }

    public LlmInspectionReportResult generateReport(
            InspectionLlmRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException(
                    "Rapor isteği boş olamaz."
            );
        }

        String prompt =
                InspectionReportPromptBuilder.build(
                        request
                );

        GenerateContentConfig config =
                GenerateContentConfig.builder()
                        .responseMimeType(
                                "application/json"
                        )
                        .responseSchema(
                                createResponseSchema()
                        )
                        .candidateCount(1)
                        .build();

        GenerateContentResponse response =
                geminiClient.models.generateContent(
                        model,
                        prompt,
                        config
                );

        if (response == null) {
            throw new IllegalStateException(
                    "Gemini yanıt döndürmedi."
            );
        }

        String responseText =
                response.text();

        if (responseText == null
                || responseText.isBlank()) {

            throw new IllegalStateException(
                    "Gemini boş rapor döndürdü."
            );
        }

        LlmInspectionReportResult result =
                parseResponse(
                        responseText
                );

        validateResult(
                result
        );

        return result;
    }

    private Schema createResponseSchema() {

        return Schema.builder()
                .type(Type.Known.OBJECT)
                .properties(
                        Map.of(
                                "title",
                                Schema.builder()
                                        .type(Type.Known.STRING)
                                        .build(),

                                "summary",
                                Schema.builder()
                                        .type(Type.Known.STRING)
                                        .build(),

                                "damageDescription",
                                Schema.builder()
                                        .type(Type.Known.STRING)
                                        .build(),

                                "repairRecommendation",
                                Schema.builder()
                                        .type(Type.Known.STRING)
                                        .build(),

                                "estimatedMinimumPrice",
                                Schema.builder()
                                        .type(Type.Known.NUMBER)
                                        .build(),

                                "estimatedMaximumPrice",
                                Schema.builder()
                                        .type(Type.Known.NUMBER)
                                        .build(),

                                "currency",
                                Schema.builder()
                                        .type(Type.Known.STRING)
                                        .enum_(
                                                List.of(
                                                        "TRY"
                                                )
                                        )
                                        .build(),

                                "priceInformation",
                                Schema.builder()
                                        .type(Type.Known.STRING)
                                        .build(),

                                "priceSourceDescription",
                                Schema.builder()
                                        .type(Type.Known.STRING)
                                        .build(),

                                "disclaimer",
                                Schema.builder()
                                        .type(Type.Known.STRING)
                                        .build()
                        )
                )
                .required(
                        List.of(
                                "title",
                                "summary",
                                "damageDescription",
                                "repairRecommendation",
                                "estimatedMinimumPrice",
                                "estimatedMaximumPrice",
                                "currency",
                                "priceInformation",
                                "priceSourceDescription",
                                "disclaimer"
                        )
                )
                .build();
    }

    private LlmInspectionReportResult parseResponse(
            String responseText
    ) {

        try {
            return objectMapper.readValue(
                    responseText,
                    LlmInspectionReportResult.class
            );

        } catch (JsonProcessingException exception) {

            throw new IllegalStateException(
                    "Gemini raporu JSON formatında okunamadı.",
                    exception
            );
        }
    }

    private void validateResult(
            LlmInspectionReportResult result
    ) {

        if (result == null) {
            throw new IllegalStateException(
                    "Gemini raporu oluşturulamadı."
            );
        }

        validateRequiredText(
                result.title,
                "Gemini rapor başlığı oluşturmadı."
        );

        validateRequiredText(
                result.summary,
                "Gemini rapor özeti oluşturmadı."
        );

        validateRequiredText(
                result.damageDescription,
                "Gemini hasar açıklaması oluşturmadı."
        );

        validateRequiredText(
                result.repairRecommendation,
                "Gemini onarım önerisi oluşturmadı."
        );

        validateRequiredText(
                result.priceInformation,
                "Gemini fiyat bilgisi oluşturmadı."
        );

        validateRequiredText(
                result.priceSourceDescription,
                "Gemini fiyat kaynağı açıklaması oluşturmadı."
        );

        validateRequiredText(
                result.disclaimer,
                "Gemini uyarı metni oluşturmadı."
        );

        if (result.estimatedMinimumPrice == null
                || result.estimatedMaximumPrice == null) {

            throw new IllegalStateException(
                    "Gemini fiyat tahmini oluşturmadı."
            );
        }

        if (result.estimatedMinimumPrice.signum() < 0
                || result.estimatedMaximumPrice.signum() < 0) {

            throw new IllegalStateException(
                    "Gemini negatif fiyat döndürdü."
            );
        }

        if (result.estimatedMinimumPrice.compareTo(
                result.estimatedMaximumPrice
        ) > 0) {

            throw new IllegalStateException(
                    "Gemini geçersiz fiyat aralığı döndürdü."
            );
        }

        if (result.currency == null
                || !"TRY".equalsIgnoreCase(
                result.currency.trim()
        )) {

            throw new IllegalStateException(
                    "Gemini geçersiz para birimi döndürdü."
            );
        }

        result.currency = "TRY";

        BigDecimal priceDifference =
                result.estimatedMaximumPrice.subtract(
                        result.estimatedMinimumPrice
                );

        if (priceDifference.compareTo(
                BigDecimal.valueOf(10_000)
        ) > 0) {

            result.estimatedMaximumPrice =
                    result.estimatedMinimumPrice.add(
                            BigDecimal.valueOf(10_000)
                    );
        }
    }

    private void validateRequiredText(
            String value,
            String errorMessage
    ) {
        if (value == null
                || value.isBlank()) {

            throw new IllegalStateException(
                    errorMessage
            );
        }
    }
}