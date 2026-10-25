package com.gorkem.vehicle_inspector.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.dto.response.AiAnalysisResponse;
import com.gorkem.vehicle_inspector.entity.DamageInspection;

/** The existing versioned JSON column preserves new observations without rewriting historical rows. */
public final class VisualAnalysisPayload {
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private VisualAnalysisPayload() {}
    public static AiAnalysisResponse read(DamageInspection inspection) {
        if (!GeminiAnalysisValidator.SCHEMA.equals(inspection.getAnalysisSchemaVersion())
                || inspection.getAnalysisPayload() == null) return null;
        try {
            return MAPPER.readValue(inspection.getAnalysisPayload(), AiAnalysisResponse.class);
        } catch (com.fasterxml.jackson.core.JsonProcessingException invalid) {
            // Historical report and history access must survive an unavailable optional payload.
            return null;
        }
    }
}
