package com.gorkem.vehicle_inspector.dto.response;

import java.util.List;

public record AiAssistantPlanResponse(String intent, boolean inScope, boolean useRag, String toolName, String reason, List<AiAssistantRetrievedContext> context) {
    public record AiAssistantRetrievedContext(String title, String category, String content, double similarity) {}
}
