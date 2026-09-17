package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.VehicleTrackingRequest;
import com.gorkem.vehicle_inspector.entity.MaintenanceRecord;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.entity.VehicleReminder;
import com.gorkem.vehicle_inspector.repository.MaintenanceRecordRepository;
import com.gorkem.vehicle_inspector.repository.VehicleReminderRepository;
import com.gorkem.vehicle_inspector.service.VehicleTrackingInitializer;
import com.gorkem.vehicle_inspector.service.ReminderScheduleCalculator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class VehicleTrackingInitializerTest {
    @Mock private MaintenanceRecordRepository maintenance;
    @Mock private VehicleReminderRepository reminders;

    private VehicleTrackingInitializer initializer;
    private User user;
    private Vehicle vehicle;

    @BeforeEach
    void setUp() {
        initializer = new VehicleTrackingInitializer(maintenance, reminders,
                new ReminderScheduleCalculator(),
                Clock.fixed(Instant.parse("2026-09-16T09:00:00Z"), ZoneOffset.UTC));
        user = mock(User.class);
        vehicle = new Vehicle("35ABC123", "Honda", "City", 2022, 50_000, user);
    }

    @Test
    void omittedTrackingDataShouldNotCreateRecords() {
        initializer.initialize(vehicle, user, null);

        verifyNoInteractions(maintenance, reminders);
        assertNull(vehicle.getNotes());
    }

    @Test
    void suppliedTrackingDataShouldCreateInitialMaintenanceAndReminders() {
        VehicleTrackingRequest request = new VehicleTrackingRequest(
                LocalDate.of(2026, 8, 1), 48_000,
                LocalDate.of(2027, 8, 1), 58_000,
                LocalDate.of(2027, 1, 10),
                LocalDate.of(2027, 2, 10),
                LocalDate.of(2027, 3, 10),
                LocalDate.of(2026, 11, 10),
                "  Kapalı garajda tutuluyor.  ");

        initializer.initialize(vehicle, user, request);

        ArgumentCaptor<MaintenanceRecord> maintenanceCaptor =
                ArgumentCaptor.forClass(MaintenanceRecord.class);
        verify(maintenance).save(maintenanceCaptor.capture());
        MaintenanceRecord record = maintenanceCaptor.getValue();
        assertEquals(48_000, record.getMileage());
        assertEquals(58_000, record.getNextRecommendedMileage());
        assertEquals(LocalDate.of(2027, 8, 1), record.getNextRecommendedDate());
        verify(reminders, times(5)).save(any(VehicleReminder.class));
        assertEquals("Kapalı garajda tutuluyor.", vehicle.getNotes());
    }

    @Test
    void partialLastMaintenanceDataShouldBeRejected() {
        VehicleTrackingRequest request = new VehicleTrackingRequest(
                LocalDate.of(2026, 8, 1), null,
                null, null, null, null, null, null, null);

        assertThrows(IllegalArgumentException.class,
                () -> initializer.initialize(vehicle, user, request));
        verifyNoInteractions(maintenance, reminders);
    }

    @Test
    void monthIntervalNeedsOnlyLastMaintenanceDate() {
        VehicleTrackingRequest request = new VehicleTrackingRequest(
                LocalDate.of(2026, 8, 31), null,
                null, null, null, null, null, null, null,
                6, null, null, null);

        initializer.initialize(vehicle, user, request);

        verifyNoInteractions(maintenance);
        ArgumentCaptor<VehicleReminder> captor = ArgumentCaptor.forClass(VehicleReminder.class);
        verify(reminders).save(captor.capture());
        assertEquals(LocalDate.of(2027, 2, 28), captor.getValue().getDueDate());
        assertNull(captor.getValue().getDueMileage());
    }

    @Test
    void mileageIntervalNeedsOnlyLastMaintenanceMileage() {
        VehicleTrackingRequest request = new VehicleTrackingRequest(
                null, 48_000,
                null, null, null, null, null, null, null,
                null, 10_000, null, null);

        initializer.initialize(vehicle, user, request);

        verifyNoInteractions(maintenance);
        ArgumentCaptor<VehicleReminder> captor = ArgumentCaptor.forClass(VehicleReminder.class);
        verify(reminders).save(captor.capture());
        assertNull(captor.getValue().getDueDate());
        assertEquals(58_000, captor.getValue().getDueMileage());
    }
}
