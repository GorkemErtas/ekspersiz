package com.gorkem.vehicle_inspector.service.report;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class GeminiNearbyGenerationConfigTest {

    @Test
    void nearbyQueriesUseStructuredJsonWithoutUnsupportedGemini36Options() {
        var service = new GeminiNearbyServiceSearchService(null, new ObjectMapper(), "gemini-3.6-flash");
        var config = service.createSearchGenerationConfig();

        assertTrue(config.candidateCount().isEmpty());
        assertTrue(config.temperature().isEmpty());
        assertEquals("application/json", config.responseMimeType().orElseThrow());
        assertTrue(config.responseSchema().isPresent());
    }
}
