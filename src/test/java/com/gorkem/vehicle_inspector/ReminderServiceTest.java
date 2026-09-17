package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.response.ReminderResponse;
import com.gorkem.vehicle_inspector.entity.ReminderType;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.entity.VehicleReminder;
import com.gorkem.vehicle_inspector.repository.AppNotificationRepository;
import com.gorkem.vehicle_inspector.repository.VehicleReminderRepository;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.ReminderService;
import com.gorkem.vehicle_inspector.service.VehicleAccessService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.*;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ReminderServiceTest {
    @Mock private VehicleReminderRepository reminders;
    @Mock private AppNotificationRepository notifications;
    @Mock private BusinessContextService businessContext;
    @Mock private VehicleAccessService vehicleAccess;

    private ReminderService service;
    private User user;
    private Vehicle vehicle;
    private final Clock clock = Clock.fixed(
            Instant.parse("2026-09-16T09:00:00Z"), ZoneOffset.UTC);

    @BeforeEach
    void setUp() {
        service = new ReminderService(reminders, notifications,
                businessContext, vehicleAccess, clock);
        user = mock(User.class);
        vehicle = new Vehicle("35ABC123", "Honda", "City", 2022, 100_000, user);
        ReflectionTestUtils.setField(vehicle, "id", 5L);
    }

    @Test
    void listShouldCalculateDateAndMileageStatusesAgainstCurrentVehicleState() {
        when(user.getId()).thenReturn(1L);
        when(user.getFullName()).thenReturn("Test User");
        VehicleReminder overdueDate = reminder(LocalDate.of(2026, 9, 15), null);
        VehicleReminder dueSoonDate = reminder(LocalDate.of(2026, 10, 16), null);
        VehicleReminder dueSoonMileage = reminder(null, 102_000);
        VehicleReminder upcoming = reminder(LocalDate.of(2026, 11, 1), 105_000);
        VehicleReminder completed = reminder(LocalDate.of(2026, 9, 1), null);
        completed.complete(LocalDateTime.of(2026, 9, 10, 12, 0));

        when(businessContext.requireUser("user@example.com")).thenReturn(user);
        when(vehicleAccess.requireVehicleIncludingArchived(5L, user)).thenReturn(vehicle);
        when(reminders.findAllByVehicleIdOrderByCompletedAtAscDueDateAscIdDesc(5L))
                .thenReturn(List.of(overdueDate, dueSoonDate, dueSoonMileage, upcoming, completed));

        List<ReminderResponse> result = service.list(5L, "user@example.com");

        assertEquals(List.of("OVERDUE", "DUE_SOON", "DUE_SOON", "UPCOMING", "COMPLETED"),
                result.stream().map(ReminderResponse::status).toList());
        assertEquals(-1, result.get(0).daysRemaining());
        assertEquals(2_000, result.get(2).mileageRemaining());
    }

    @Test
    void deleteShouldDetachHistoricalNotificationsBeforeDeletingReminder() {
        VehicleReminder reminder = reminder(LocalDate.of(2026, 10, 1), null);
        ReflectionTestUtils.setField(reminder, "id", 7L);
        when(businessContext.requireUser("user@example.com")).thenReturn(user);
        when(vehicleAccess.requireActiveVehicle(5L, user)).thenReturn(vehicle);
        when(reminders.findByIdAndVehicleId(7L, 5L)).thenReturn(java.util.Optional.of(reminder));

        service.delete(5L, 7L, "user@example.com");

        var ordered = inOrder(notifications, reminders);
        ordered.verify(notifications).detachReminder(7L);
        ordered.verify(reminders).delete(reminder);
    }

    private VehicleReminder reminder(LocalDate dueDate, Integer dueMileage) {
        return new VehicleReminder(vehicle, user, ReminderType.PERIODIC_MAINTENANCE,
                null, dueDate, dueMileage, null,
                LocalDateTime.of(2026, 9, 1, 12, 0));
    }
}
