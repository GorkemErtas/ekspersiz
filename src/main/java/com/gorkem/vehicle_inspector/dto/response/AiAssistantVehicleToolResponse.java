package com.gorkem.vehicle_inspector.dto.response;

public record AiAssistantVehicleToolResponse(Long id, String plate, String brand, String model, Integer modelYear, Integer mileage, boolean primaryVehicle) {}
