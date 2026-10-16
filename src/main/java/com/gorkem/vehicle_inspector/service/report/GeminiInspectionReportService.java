package com.gorkem.vehicle_inspector.service.report;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.genai.Client;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.Schema;
import com.google.genai.types.Type;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.InspectionPriceEstimateResult;
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
            @Value("${application.gemini.model}") String model
    ) {
        this.geminiClient = geminiClient;
        this.objectMapper = objectMapper;
        this.model = model;
    }

    /**
     * Gemini estimates ONLY repair prices and pricing explanations.
     * Narrative/title/disclaimer are generated locally from the ML results.
     * Keep the same public result/persistence contract for existing clients.
     */
    public LlmInspectionReportResult generateReport(InspectionLlmRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Rapor isteği boş olamaz.");
        }

        String prompt = InspectionReportPromptBuilder.build(request);
        GenerateContentConfig config = GenerateContentConfig.builder()
                .responseMimeType("application/json")
                .responseSchema(createResponseSchema())
                .candidateCount(1)
                .build();

        GenerateContentResponse response =
                geminiClient.models.generateContent(model, prompt, config);
        if (response == null || response.text() == null || response.text().isBlank()) {
            throw new IllegalStateException("Gemini boş fiyat tahmini döndürdü.");
        }

        InspectionPriceEstimateResult price = validatePrice(
                parsePriceResponse(response.text())
        );
        return InspectionReportNarrativeBuilder.build(request, price);
    }

    private Schema createResponseSchema() {
        return Schema.builder()
                .type(Type.Known.OBJECT)
                .properties(Map.of(
                        "estimatedMinimumPrice", Schema.builder()
                                .type(Type.Known.NUMBER).build(),
                        "estimatedMaximumPrice", Schema.builder()
                                .type(Type.Known.NUMBER).build(),
                        "currency", Schema.builder()
                                .type(Type.Known.STRING).enum_(List.of("TRY")).build(),
                        "priceInformation", Schema.builder()
                                .type(Type.Known.STRING).build(),
                        "priceSourceDescription", Schema.builder()
                                .type(Type.Known.STRING).build()
                ))
                .required(List.of(
                        "estimatedMinimumPrice",
                        "estimatedMaximumPrice",
                        "currency",
                        "priceInformation",
                        "priceSourceDescription"
                ))
                .build();
    }

    private InspectionPriceEstimateResult parsePriceResponse(String json) {
        try {
            return objectMapper.readValue(json, InspectionPriceEstimateResult.class);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException(
                    "Gemini fiyat tahmini JSON formatında okunamadı.", exception
            );
        }
    }

    static InspectionPriceEstimateResult validatePrice(
            InspectionPriceEstimateResult result
    ) {
        if (result == null || result.estimatedMinimumPrice() == null
                || result.estimatedMaximumPrice() == null) {
            throw new IllegalStateException("Gemini fiyat tahmini oluşturmadı.");
        }

        BigDecimal minimum = result.estimatedMinimumPrice();
        BigDecimal maximum = result.estimatedMaximumPrice();

        if (minimum.signum() < 0 || maximum.signum() < 0) {
            throw new IllegalStateException("Gemini negatif fiyat döndürdü.");
        }
        if (minimum.compareTo(maximum) > 0) {
            throw new IllegalStateException("Gemini geçersiz fiyat aralığı döndürdü.");
        }
        if (result.currency() == null || !"TRY".equalsIgnoreCase(result.currency().trim())) {
            throw new IllegalStateException("Gemini geçersiz para birimi döndürdü.");
        }
        requireText(result.priceInformation(), "Gemini fiyat bilgisi oluşturmadı.");
        requireText(result.priceSourceDescription(), "Gemini fiyat kaynağı açıklaması oluşturmadı.");

        // Preserve the exact pre-existing price interval policy.
        if (maximum.subtract(minimum).compareTo(BigDecimal.valueOf(10_000)) > 0) {
            maximum = minimum.add(BigDecimal.valueOf(10_000));
        }
        return new InspectionPriceEstimateResult(
                minimum, maximum, "TRY",
                result.priceInformation(), result.priceSourceDescription()
        );
    }

    private static void requireText(String value, String message) {
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(message);
        }
    }
}
