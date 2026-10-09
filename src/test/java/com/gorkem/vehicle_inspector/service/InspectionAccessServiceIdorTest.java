package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.DamageInspection;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

class InspectionAccessServiceIdorTest {

    private DamageInspectionRepository repository;
    private BusinessContextService businessContext;
    private InspectionAccessService accessService;

    @BeforeEach
    void setUp() {
        repository = mock(DamageInspectionRepository.class);
        businessContext = mock(BusinessContextService.class);
        accessService = new InspectionAccessService(repository, businessContext);
    }

    @Test
    void anotherPersonalUserCannotReadInspectionByGuessingItsId() {
        User owner = mock(User.class);
        User requester = mock(User.class);
        Vehicle vehicle = mock(Vehicle.class);
        DamageInspection inspection = mock(DamageInspection.class);
        when(owner.getId()).thenReturn(10L);
        when(requester.getId()).thenReturn(20L);
        when(inspection.getId()).thenReturn(50L);
        when(inspection.getVehicle()).thenReturn(vehicle);
        when(vehicle.getUser()).thenReturn(owner);
        when(businessContext.findMembership(requester)).thenReturn(Optional.empty());
        when(repository.findById(50L)).thenReturn(Optional.of(inspection));

        assertThrows(ResourceNotFoundException.class,
                () -> accessService.requireInspection(50L, requester));
    }

    @Test
    void ownerCanReadOwnPersonalInspection() {
        User owner = mock(User.class);
        Vehicle vehicle = mock(Vehicle.class);
        DamageInspection inspection = mock(DamageInspection.class);
        when(owner.getId()).thenReturn(10L);
        when(inspection.getVehicle()).thenReturn(vehicle);
        when(vehicle.getUser()).thenReturn(owner);
        when(businessContext.findMembership(owner)).thenReturn(Optional.empty());
        when(repository.findById(50L)).thenReturn(Optional.of(inspection));

        assertSame(inspection, accessService.requireInspection(50L, owner));
    }

    @Test
    void anotherPersonalUserCannotModifyInspectionByGuessingItsId() {
        User owner = mock(User.class);
        User requester = mock(User.class);
        Vehicle vehicle = mock(Vehicle.class);
        DamageInspection inspection = mock(DamageInspection.class);
        when(owner.getId()).thenReturn(10L);
        when(requester.getId()).thenReturn(20L);
        when(inspection.getId()).thenReturn(50L);
        when(inspection.getVehicle()).thenReturn(vehicle);
        when(vehicle.getUser()).thenReturn(owner);
        when(businessContext.findMembership(requester)).thenReturn(Optional.empty());
        when(repository.findByIdForUpdate(50L)).thenReturn(Optional.of(inspection));

        assertThrows(ResourceNotFoundException.class,
                () -> accessService.requireInspectionForUpdate(50L, requester));
    }
}
