package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.ReminderType;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record ReminderResponse(
        Long id, Long vehicleId, ReminderType reminderType, String title,
        LocalDate dueDate, Integer dueMileage, String note, String status,
        Integer daysRemaining, Integer mileageRemaining,
        LocalDate sourceDate, Integer sourceMileage, Integer intervalMonths,
        Integer intervalMileage, Boolean firstInspection,
        LocalDateTime completedAt, Long createdByUserId, String createdByName
) {}
