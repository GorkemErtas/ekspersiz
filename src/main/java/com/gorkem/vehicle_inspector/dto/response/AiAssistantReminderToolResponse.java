package com.gorkem.vehicle_inspector.dto.response;

import java.time.LocalDate;
public record AiAssistantReminderToolResponse(Long id, String type, String title, LocalDate dueDate, Integer dueMileage) {}
