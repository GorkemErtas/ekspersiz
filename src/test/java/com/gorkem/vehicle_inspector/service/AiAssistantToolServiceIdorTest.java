package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.repository.VehicleReminderRepository;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

class AiAssistantToolServiceIdorTest {
    private BusinessContextService businessContext;
    private VehicleAccessService vehicleAccess;
    private VehicleReminderRepository reminders;
    private DamageInspectionRepository inspections;
    private AiAssistantToolService service;
    private User requester;

    @BeforeEach
    void setUp() {
        businessContext = mock(BusinessContextService.class);
        vehicleAccess = mock(VehicleAccessService.class);
        reminders = mock(VehicleReminderRepository.class);
        inspections = mock(DamageInspectionRepository.class);
        service = new AiAssistantToolService(businessContext, mock(VehicleRepository.class),
                vehicleAccess, reminders, inspections);
        requester = mock(User.class);
        when(businessContext.requireUser("requester@example.com")).thenReturn(requester);
        when(vehicleAccess.requireActiveVehicle(99L, requester))
                .thenThrow(new ResourceNotFoundException("Araç bulunamadı."));
    }

    @Test
    void cannotReadAnotherUsersVehicleThroughAssistant() {
        assertThrows(ResourceNotFoundException.class,
                () -> service.getVehicle(99L, "requester@example.com"));
    }

    @Test
    void cannotReadAnotherUsersRemindersThroughAssistant() {
        assertThrows(ResourceNotFoundException.class,
                () -> service.getUpcomingReminders(99L, "requester@example.com"));
        verifyNoInteractions(reminders);
    }

    @Test
    void cannotReadAnotherUsersDamageHistoryThroughAssistant() {
        assertThrows(ResourceNotFoundException.class,
                () -> service.getDamageHistory(99L, "requester@example.com"));
        verifyNoInteractions(inspections);
    }
}
