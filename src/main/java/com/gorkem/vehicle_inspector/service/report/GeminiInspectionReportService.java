package com.gorkem.vehicle_inspector.service.report;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.genai.Client;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.GoogleSearch;
import com.google.genai.types.Tool;
import com.google.genai.types.Schema;
import com.google.genai.types.Type;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.InspectionPriceEstimateResult;
import com.gorkem.vehicle_inspector.dto.llm.LlmInspectionReportResult;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@Service
public class GeminiInspectionReportService {

    private static final Logger LOGGER = LoggerFactory.getLogger(GeminiInspectionReportService.class);
    private static final int MAX_EVIDENCE_CHARS = 2500;

    private final Client geminiClient;
    private final ObjectMapper objectMapper;
    private final String model;
    private final boolean webSearchEnabled;

    public GeminiInspectionReportService(
            Client geminiClient,
            ObjectMapper objectMapper,
            @Value("${application.gemini.model}") String model,
            @Value("${application.pricing.web-search.enabled:true}") boolean webSearchEnabled
    ) {
        this.geminiClient = geminiClient;
        this.objectMapper = objectMapper;
        this.model = model;
        this.webSearchEnabled = webSearchEnabled;
    }

    /**
     * Gemini estimates ONLY repair prices and pricing explanations.
     * Narrative/title/disclaimer are generated locally from the visual observations.
     * Keep the same public result/persistence contract for existing clients.
     */
    public LlmInspectionReportResult generateReport(InspectionLlmRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Rapor isteği boş olamaz.");
        }

        WebPriceEvidence evidence = lookUpPriceEvidence(request);
        String prompt = InspectionReportPromptBuilder.build(
                request, evidence == null ? null : evidence.summary()
        );
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

        InspectionPriceEstimateResult rawPrice = validatePrice(parsePriceResponse(response.text()));

        // Keep price evidence internal; do not expose raw URLs in user-facing reports.
        String source = evidence == null
                ? "Güncel web fiyatı doğrulanamadı veya arama kapalı; genel piyasa, araç, şehir "
                    + "ve görsel onarım bilgileri kullanıldı. Güncel bir servis teklifi değildir."
                : "Çevrimiçi piyasa fiyat örnekleri, araç, şehir ve önerilen onarım işlemleri "
                    + "dikkate alınarak yaklaşık tahmin oluşturuldu. Kesin servis teklifi değildir.";

        InspectionPriceEstimateResult price = new InspectionPriceEstimateResult(
                rawPrice.estimatedMinimumPrice(), rawPrice.estimatedMaximumPrice(),
                rawPrice.currency(), removeLinks(rawPrice.priceInformation()), source
        );
        return InspectionReportNarrativeBuilder.build(request, price);
    }

    private WebPriceEvidence lookUpPriceEvidence(InspectionLlmRequest request) {
        if (!webSearchEnabled || request.vehicle() == null) return null;
        try {
            GenerateContentConfig config = GenerateContentConfig.builder()
                    .tools(Tool.builder().googleSearch(GoogleSearch.builder()).build())
                    .candidateCount(1).build();
            GenerateContentResponse response = geminiClient.models.generateContent(
                    model, InspectionReportPromptBuilder.buildWebSearchPrompt(request), config
            );
            WebPriceEvidence evidence = extractWebEvidence(response);
            if (evidence == null) {
                LOGGER.info("Inspection pricing: no grounded web sources, using baseline estimate.");
            }
            return evidence;
        } catch (RuntimeException exception) {
            LOGGER.warn("Inspection pricing: web search unavailable ({}); using baseline estimate.",
                    exception.getClass().getSimpleName());
            return null;
        }
    }

    static WebPriceEvidence extractWebEvidence(GenerateContentResponse response) {
        if (response == null || response.text() == null || response.text().isBlank()) return null;
        List<String> sources = response.candidates().orElse(List.of()).stream()
                .flatMap(candidate -> candidate.groundingMetadata().stream())
                .flatMap(metadata -> metadata.groundingChunks().orElse(List.of()).stream())
                .flatMap(chunk -> chunk.web().stream())
                .flatMap(web -> web.uri().stream())
                .filter(url -> url.startsWith("https://") && url.length() <= 350)
                .distinct().limit(2).toList();
        if (sources.isEmpty()) return null;
        String summary = response.text().trim();
        if (summary.length() > MAX_EVIDENCE_CHARS) {
            summary = summary.substring(0, MAX_EVIDENCE_CHARS);
        }
        return new WebPriceEvidence(summary, sources);
    }

    record WebPriceEvidence(String summary, List<String> sourceUrls) {
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

        // Do not silently clip the range for premium vehicles or multi-panel repairs.
        return new InspectionPriceEstimateResult(
                minimum, maximum, "TRY",
                result.priceInformation(), result.priceSourceDescription()
        );
    }

    // Gemini may occasionally include a source URL even when the prompt forbids it.
    // Remove only links from its user-facing price explanation; preserve numeric costs.
    static String removeLinks(String explanation) {
        if (explanation == null) return null;
        return explanation.replaceAll("(?i)(?:https?://|www\\.)\\S+", "")
                .replaceAll("(?i)\\bKaynaklar\\s*:\\s*$", "")
                .replaceAll(" {2,}", " ")
                .trim();
    }

    private static void requireText(String value, String message) {
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(message);
        }
    }
}
