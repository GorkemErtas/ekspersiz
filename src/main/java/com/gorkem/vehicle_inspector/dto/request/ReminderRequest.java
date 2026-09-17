package com.gorkem.vehicle_inspector.dto.request;

import com.gorkem.vehicle_inspector.entity.ReminderType;
import jakarta.validation.constraints.*;
import java.time.LocalDate;

public record ReminderRequest(
        @NotNull ReminderType reminderType,
        @Size(max = 120) String title,
        LocalDate dueDate,
        @Min(0) @Max(2_000_000) Integer dueMileage,
        @Size(max = 1000) String note,
        LocalDate sourceDate,
        @Min(0) @Max(2_000_000) Integer sourceMileage,
        @Min(1) @Max(600) Integer intervalMonths,
        @Min(1) @Max(2_000_000) Integer intervalMileage,
        Boolean firstInspection
) {
    public ReminderRequest(ReminderType reminderType, String title, LocalDate dueDate,
                           Integer dueMileage, String note) {
        this(reminderType, title, dueDate, dueMileage, note,
                null, null, null, null, null);
    }
}
