package com.gorkem.vehicle_inspector.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.dto.response.*;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class AiAssistantToolContextService {
    private static final int MAX_HISTORY_ITEMS = 5;

    private final AiAssistantToolService tools;
    private final ObjectMapper objectMapper;

    public AiAssistantToolContextService(AiAssistantToolService tools, ObjectMapper objectMapper) {
        this.tools = tools;
        this.objectMapper = objectMapper;
    }

    public AiAssistantVehicleToolResponse getVehicle(Long vehicleId, String email) {
        return tools.getVehicle(vehicleId, email);
    }

    public String build(String toolName, Long vehicleId, String email) {
        Object safeContext = switch (toolName) {
            case "getMyVehicles" -> vehicles(email);
            case "getUpcomingReminders" -> reminders(vehicleId, email);
            case "getDamageHistory" -> damageHistory(vehicleId, email);
            default -> throw new IllegalArgumentException("Desteklenmeyen AI tool: " + toolName);
        };
        try {
            return objectMapper.writeValueAsString(safeContext);
        } catch (JsonProcessingException exc) {
            throw new IllegalStateException("AI tool context serialize edilemedi.", exc);
        }
    }

    private List<Map<String, Object>> vehicles(String email) {
        return tools.getMyVehicles(email).stream()
                .map(vehicle -> {
                    Map<String, Object> data = new LinkedHashMap<>();
                    data.put("vehicleId", vehicle.id());
                    data.put("brand", vehicle.brand());
                    data.put("model", vehicle.model());
                    data.put("modelYear", vehicle.modelYear());
                    data.put("mileage", vehicle.mileage());
                    data.put("primaryVehicle", vehicle.primaryVehicle());
                    return data;
                })
                .toList();
    }

    private List<Map<String, Object>> reminders(Long vehicleId, String email) {
        return tools.getUpcomingReminders(vehicleId, email).stream()
                .limit(MAX_HISTORY_ITEMS)
                .map(reminder -> {
                    Map<String, Object> data = new LinkedHashMap<>();
                    data.put("type", reminder.type());
                    data.put("title", reminder.title());
                    data.put("dueDate", reminder.dueDate());
                    data.put("dueMileage", reminder.dueMileage());
                    return data;
                })
                .toList();
    }

    private List<Map<String, Object>> damageHistory(Long vehicleId, String email) {
        return tools.getDamageHistory(vehicleId, email).stream()
                .limit(MAX_HISTORY_ITEMS)
                .map(damage -> {
                    Map<String, Object> data = new LinkedHashMap<>();
                    data.put("severity", damage.severity());
                    data.put("confidenceScore", damage.confidenceScore());
                    data.put("message", damage.message());
                    data.put("completedAt", damage.completedAt());
                    return data;
                })
                .toList();
    }
}
