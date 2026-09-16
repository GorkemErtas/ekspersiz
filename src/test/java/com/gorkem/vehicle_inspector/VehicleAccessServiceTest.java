package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.VehicleAccessService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class VehicleAccessServiceTest {
    @Mock private VehicleRepository vehicles;
    @Mock private BusinessContextService businessContext;

    private VehicleAccessService service;

    @BeforeEach
    void setUp() {
        service = new VehicleAccessService(vehicles, businessContext);
    }

    @Test
    void personalUserShouldAccessOnlyOwnActiveVehicle() {
        User user = mock(User.class);
        when(user.getId()).thenReturn(1L);
        when(businessContext.findMembership(user)).thenReturn(Optional.empty());
        Vehicle vehicle = new Vehicle("35ABC123", "Honda", "City", 2022, 20_000, user);
        when(vehicles.findByIdAndUserIdAndArchivedFalse(5L, 1L))
                .thenReturn(Optional.of(vehicle));

        assertSame(vehicle, service.requireActiveVehicle(5L, user));
        verify(vehicles, never()).findByIdAndBusinessAccountIdAndArchivedFalse(anyLong(), anyLong());
    }

    @Test
    void companyMemberShouldAccessSharedCompanyVehicle() {
        User user = mock(User.class);
        BusinessAccount company = new BusinessAccount("ABC Ekspertiz");
        ReflectionTestUtils.setField(company, "id", 10L);
        when(businessContext.findMembership(user)).thenReturn(Optional.of(mock(BusinessMember.class)));
        when(businessContext.requireBusinessAccount(user)).thenReturn(company);
        Vehicle vehicle = new Vehicle("35ABC123", "Honda", "City", 2022, 20_000, company);
        when(vehicles.findByIdAndBusinessAccountIdAndArchivedFalse(5L, 10L))
                .thenReturn(Optional.of(vehicle));

        assertSame(vehicle, service.requireActiveVehicle(5L, user));
        verify(vehicles, never()).findByIdAndUserIdAndArchivedFalse(anyLong(), anyLong());
    }

    @Test
    void userOutsideVehicleScopeShouldBeRejected() {
        User user = mock(User.class);
        when(user.getId()).thenReturn(2L);
        when(businessContext.findMembership(user)).thenReturn(Optional.empty());
        when(vehicles.findByIdAndUserIdAndArchivedFalse(5L, 2L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class,
                () -> service.requireActiveVehicle(5L, user));
    }

    @Test
    void archivedVehicleShouldRemainAvailableForHistoryButNotForChanges() {
        User user = mock(User.class);
        when(user.getId()).thenReturn(1L);
        when(businessContext.findMembership(user)).thenReturn(Optional.empty());
        Vehicle archived = new Vehicle("35ABC123", "Honda", "City", 2022, 20_000, user);
        archived.setArchived(true);
        when(vehicles.findByIdAndUserId(5L, 1L)).thenReturn(Optional.of(archived));
        when(vehicles.findByIdAndUserIdAndArchivedFalse(5L, 1L)).thenReturn(Optional.empty());

        assertSame(archived, service.requireVehicleIncludingArchived(5L, user));
        assertThrows(ResourceNotFoundException.class,
                () -> service.requireActiveVehicle(5L, user));
    }
}
