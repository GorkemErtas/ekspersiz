package com.gorkem.vehicle_inspector.dto.response;

import java.util.List;

public record AiAssistantChatResponse(String intent, String answer, boolean quotaConsumed, int remainingToday, List<String> toolsUsed) {}
