package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.DamageInspection;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class InspectionAccessServiceBusinessIdorTest {
    private DamageInspectionRepository repository;
    private BusinessContextService businessContext;
    private InspectionAccessService service;

    @BeforeEach
    void setUp() {
        repository = mock(DamageInspectionRepository.class);
        businessContext = mock(BusinessContextService.class);
        service = new InspectionAccessService(repository, businessContext);
    }

    @Test
    void personalUserCannotReadBusinessInspection() {
        User requester = mock(User.class);
        Vehicle vehicle = mock(Vehicle.class);
        DamageInspection inspection = mock(DamageInspection.class);
        when(inspection.getId()).thenReturn(41L);
        when(inspection.getVehicle()).thenReturn(vehicle);
        when(vehicle.getBusinessAccount()).thenReturn(mock(BusinessAccount.class));
        when(businessContext.findMembership(requester)).thenReturn(Optional.empty());
        when(repository.findById(41L)).thenReturn(Optional.of(inspection));

        assertThrows(ResourceNotFoundException.class,
                () -> service.requireInspection(41L, requester));
    }

    @Test
    void personalUserCannotModifyBusinessInspection() {
        User requester = mock(User.class);
        Vehicle vehicle = mock(Vehicle.class);
        DamageInspection inspection = mock(DamageInspection.class);
        when(inspection.getId()).thenReturn(41L);
        when(inspection.getVehicle()).thenReturn(vehicle);
        when(vehicle.getBusinessAccount()).thenReturn(mock(BusinessAccount.class));
        when(businessContext.findMembership(requester)).thenReturn(Optional.empty());
        when(repository.findByIdForUpdate(41L)).thenReturn(Optional.of(inspection));

        assertThrows(ResourceNotFoundException.class,
                () -> service.requireInspectionForUpdate(41L, requester));
    }

    @Test
    void memberOfAnotherBusinessCannotReadInspection() {
        User requester = mock(User.class);
        BusinessAccount ownBusiness = mock(BusinessAccount.class);
        BusinessAccount otherBusiness = mock(BusinessAccount.class);
        BusinessMember membership = mock(BusinessMember.class);
        Vehicle vehicle = mock(Vehicle.class);
        DamageInspection inspection = mock(DamageInspection.class);
        when(ownBusiness.getId()).thenReturn(1L);
        when(otherBusiness.getId()).thenReturn(2L);
        when(membership.getBusinessAccount()).thenReturn(ownBusiness);
        when(businessContext.findMembership(requester)).thenReturn(Optional.of(membership));
        when(vehicle.getBusinessAccount()).thenReturn(otherBusiness);
        when(inspection.getId()).thenReturn(41L);
        when(inspection.getVehicle()).thenReturn(vehicle);
        when(repository.findById(41L)).thenReturn(Optional.of(inspection));

        assertThrows(ResourceNotFoundException.class,
                () -> service.requireInspection(41L, requester));
    }

    @Test
    void memberOfAnotherBusinessCannotModifyInspection() {
        User requester = mock(User.class);
        BusinessAccount ownBusiness = mock(BusinessAccount.class);
        BusinessAccount otherBusiness = mock(BusinessAccount.class);
        BusinessMember membership = mock(BusinessMember.class);
        Vehicle vehicle = mock(Vehicle.class);
        DamageInspection inspection = mock(DamageInspection.class);
        when(ownBusiness.getId()).thenReturn(1L);
        when(otherBusiness.getId()).thenReturn(2L);
        when(membership.getBusinessAccount()).thenReturn(ownBusiness);
        when(businessContext.findMembership(requester)).thenReturn(Optional.of(membership));
        when(vehicle.getBusinessAccount()).thenReturn(otherBusiness);
        when(inspection.getId()).thenReturn(41L);
        when(inspection.getVehicle()).thenReturn(vehicle);
        when(repository.findByIdForUpdate(41L)).thenReturn(Optional.of(inspection));

        assertThrows(ResourceNotFoundException.class,
                () -> service.requireInspectionForUpdate(41L, requester));
    }

    @Test
    void memberOfSameBusinessCanReadInspection() {
        User requester = mock(User.class);
        BusinessAccount business = mock(BusinessAccount.class);
        BusinessMember membership = mock(BusinessMember.class);
        Vehicle vehicle = mock(Vehicle.class);
        DamageInspection inspection = mock(DamageInspection.class);
        when(business.getId()).thenReturn(1L);
        when(membership.getBusinessAccount()).thenReturn(business);
        when(businessContext.findMembership(requester)).thenReturn(Optional.of(membership));
        when(vehicle.getBusinessAccount()).thenReturn(business);
        when(inspection.getVehicle()).thenReturn(vehicle);
        when(repository.findById(41L)).thenReturn(Optional.of(inspection));

        assertSame(inspection, service.requireInspection(41L, requester));
    }
}
