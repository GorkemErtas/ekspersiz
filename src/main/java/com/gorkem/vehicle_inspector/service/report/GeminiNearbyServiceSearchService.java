package com.gorkem.vehicle_inspector.service.report;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.genai.Client;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.Schema;
import com.google.genai.types.Type;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.NearbyServiceSearchResult;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.Objects;

@Service
public class GeminiNearbyServiceSearchService {

    private final Client geminiClient;
    private final ObjectMapper objectMapper;
    private final String model;

    public GeminiNearbyServiceSearchService(
            Client geminiClient,
            ObjectMapper objectMapper,
            @Value("${application.gemini.model}")
            String model
    ) {
        this.geminiClient = geminiClient;
        this.objectMapper = objectMapper;
        this.model = model;
    }

    public NearbyServiceSearchResult generateSearchQueries(
            InspectionLlmRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException(
                    "Servis arama isteği boş olamaz."
            );
        }

        String prompt =
                NearbyServicePromptBuilder.build(
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

        if (response == null
                || response.text() == null
                || response.text().isBlank()) {

            throw new IllegalStateException(
                    "Gemini servis arama sorgusu oluşturmadı."
            );
        }

        NearbyServiceSearchResult result =
                parseResponse(
                        response.text()
                );

        validateResult(result);

        return result;
    }

    private Schema createResponseSchema() {
        return Schema.builder()
                .type(Type.Known.OBJECT)
                .properties(
                        Map.of(
                                "searchQueries",
                                Schema.builder()
                                        .type(Type.Known.ARRAY)
                                        .items(
                                                Schema.builder()
                                                        .type(
                                                                Type.Known.STRING
                                                        )
                                                        .build()
                                        )
                                        .build()
                        )
                )
                .required(
                        List.of(
                                "searchQueries"
                        )
                )
                .build();
    }

    private NearbyServiceSearchResult parseResponse(
            String responseText
    ) {
        try {
            return objectMapper.readValue(
                    responseText,
                    NearbyServiceSearchResult.class
            );

        } catch (JsonProcessingException exception) {

            throw new IllegalStateException(
                    "Gemini servis arama sonucu okunamadı.",
                    exception
            );
        }
    }

    private void validateResult(
            NearbyServiceSearchResult result
    ) {
        if (result == null
                || result.searchQueries == null
                || result.searchQueries.isEmpty()) {

            throw new IllegalStateException(
                    "Gemini servis arama sorgusu üretmedi."
            );
        }

        result.searchQueries =
                result.searchQueries.stream()
                        .filter(Objects::nonNull)
                        .map(String::trim)
                        .filter(query -> !query.isBlank())
                        .distinct()
                        .limit(4)
                        .toList();

        if (result.searchQueries.isEmpty()) {
            throw new IllegalStateException(
                    "Gemini geçerli servis arama sorgusu üretmedi."
            );
        }
    }
}