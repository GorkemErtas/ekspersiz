package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AiAssistantChatRequest(@NotBlank @Size(max = 2000) String question, Long vehicleId) {}
