package com.gorkem.vehicle_inspector.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

public record AiAssistantPlanResponse(
        String intent,
        @JsonProperty("in_scope") boolean inScope,
        @JsonProperty("use_rag") boolean useRag,
        @JsonProperty("tool_name") String toolName,
        String reason,
        @JsonProperty("automotive_relevance") double automotiveRelevance,
        @JsonProperty("assistant_capability") double assistantCapability,
        List<AiAssistantRetrievedContext> context) {

    public record AiAssistantRetrievedContext(
            String title, String category, String content, double similarity) {}
}
