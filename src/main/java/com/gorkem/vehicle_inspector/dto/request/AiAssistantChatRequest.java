package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public record AiAssistantChatRequest(
        @NotBlank @Size(max = 2000) String question,
        Long vehicleId,
        @Size(max = 6) List<@Valid HistoryMessage> history
) {
    public record HistoryMessage(
            @NotBlank @Size(max = 16) String role,
            @NotBlank @Size(max = 2000) String content
    ) {}
}
