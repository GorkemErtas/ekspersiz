package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.MaintenanceRequest;
import com.gorkem.vehicle_inspector.entity.MaintenanceRecord;
import com.gorkem.vehicle_inspector.entity.MaintenanceType;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.repository.MaintenanceRecordRepository;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.MaintenanceService;
import com.gorkem.vehicle_inspector.service.VehicleAccessService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.*;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MaintenanceServiceTest {
    @Mock private MaintenanceRecordRepository records;
    @Mock private BusinessContextService businessContext;
    @Mock private VehicleAccessService vehicleAccess;

    private MaintenanceService service;
    private User user;
    private Vehicle vehicle;

    @BeforeEach
    void setUp() {
        service = new MaintenanceService(records, businessContext, vehicleAccess,
                Clock.fixed(Instant.parse("2026-09-16T09:00:00Z"), ZoneOffset.UTC));
        user = mock(User.class);
        lenient().when(user.getId()).thenReturn(1L);
        lenient().when(user.getFullName()).thenReturn("Test User");
        vehicle = new Vehicle("35ABC123", "Honda", "City", 2022, 50_000, user);
        ReflectionTestUtils.setField(vehicle, "id", 5L);
    }

    @Test
    void createShouldStoreVehicleCreatorAndRecommendations() {
        MaintenanceRequest request = request(LocalDate.of(2026, 9, 1), 50_000,
                LocalDate.of(2027, 9, 1), 60_000);
        when(businessContext.requireUser("user@example.com")).thenReturn(user);
        when(vehicleAccess.requireActiveVehicle(5L, user)).thenReturn(vehicle);
        when(records.save(any())).thenAnswer(call -> call.getArgument(0));

        var response = service.create(5L, request, "user@example.com");

        ArgumentCaptor<MaintenanceRecord> captor = ArgumentCaptor.forClass(MaintenanceRecord.class);
        verify(records).save(captor.capture());
        assertSame(vehicle, captor.getValue().getVehicle());
        assertSame(user, captor.getValue().getCreatedBy());
        assertEquals(60_000, response.nextRecommendedMileage());
        assertEquals("Test User", response.createdByName());
    }

    @Test
    void listShouldAllowArchivedVehicleHistoryReads() {
        when(businessContext.requireUser("user@example.com")).thenReturn(user);
        when(vehicleAccess.requireVehicleIncludingArchived(5L, user)).thenReturn(vehicle);
        when(records.findAllByVehicleIdOrderByMaintenanceDateDescIdDesc(5L))
                .thenReturn(List.of());

        assertTrue(service.list(5L, "user@example.com").isEmpty());
        verify(vehicleAccess).requireVehicleIncludingArchived(5L, user);
    }

    @Test
    void createShouldRejectRecommendationBeforeMaintenanceValue() {
        when(businessContext.requireUser("user@example.com")).thenReturn(user);
        when(vehicleAccess.requireActiveVehicle(5L, user)).thenReturn(vehicle);
        MaintenanceRequest request = request(LocalDate.of(2026, 9, 1), 50_000,
                LocalDate.of(2026, 8, 1), 49_999);

        assertThrows(IllegalArgumentException.class,
                () -> service.create(5L, request, "user@example.com"));
        verify(records, never()).save(any());
    }

    private MaintenanceRequest request(LocalDate date, int mileage,
                                       LocalDate nextDate, int nextMileage) {
        return new MaintenanceRequest(MaintenanceType.PERIODIC_MAINTENANCE,
                date, mileage, new BigDecimal("1250.00"), "Periyodik bakım",
                nextDate, nextMileage);
    }
}
