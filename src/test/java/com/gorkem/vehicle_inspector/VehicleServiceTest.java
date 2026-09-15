package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.response.VehicleResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.SubscriptionService;
import com.gorkem.vehicle_inspector.service.VehicleService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class VehicleServiceTest {

    @Mock
    private VehicleRepository vehicleRepository;

    @Mock
    private SubscriptionService subscriptionService;

    @Mock
    private BusinessContextService businessContextService;

    private VehicleService service;

    @BeforeEach
    void setUp() {
        service = new VehicleService(
                vehicleRepository,
                subscriptionService,
                businessContextService
        );
    }

    @Test
    void individualUserShouldSeeOwnVehicles() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);
        when(user.getAccountType())
                .thenReturn(AccountType.INDIVIDUAL);

        when(businessContextService.requireUser(
                "user@example.com"
        )).thenReturn(user);

        Vehicle vehicle = new Vehicle(
                "35ABC123",
                "BMW",
                "320i",
                2022,
                30000,
                user
        );

        when(vehicleRepository
                .findAllByUserIdAndArchivedFalseOrderByIdDesc(1L))
                .thenReturn(List.of(vehicle));

        List<VehicleResponse> result =
                service.getMyVehicles(
                        "user@example.com"
                );

        assertEquals(1, result.size());

        verify(vehicleRepository)
                .findAllByUserIdAndArchivedFalseOrderByIdDesc(1L);

        verify(
                vehicleRepository,
                never()
        ).findAllByBusinessAccountIdAndArchivedFalseOrderByIdDesc(
                anyLong()
        );
    }

    @Test
    void businessMemberShouldSeeBusinessVehicles() {
        User user = mock(User.class);

        when(user.getAccountType())
                .thenReturn(AccountType.BUSINESS);

        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        ReflectionTestUtils.setField(
                businessAccount,
                "id",
                10L
        );

        when(businessContextService.requireUser(
                "member@example.com"
        )).thenReturn(user);

        when(businessContextService.requireBusinessAccount(user))
                .thenReturn(businessAccount);

        Vehicle vehicle = new Vehicle(
                "35ABC123",
                "BMW",
                "320i",
                2022,
                30000,
                businessAccount
        );

        when(vehicleRepository
                .findAllByBusinessAccountIdAndArchivedFalseOrderByIdDesc(
                        10L
                ))
                .thenReturn(List.of(vehicle));

        List<VehicleResponse> result =
                service.getMyVehicles(
                        "member@example.com"
                );

        assertEquals(1, result.size());

        verify(vehicleRepository)
                .findAllByBusinessAccountIdAndArchivedFalseOrderByIdDesc(
                        10L
                );

        verify(
                vehicleRepository,
                never()
        ).findAllByUserIdAndArchivedFalseOrderByIdDesc(
                anyLong()
        );
    }

    @Test
    void businessUserShouldNotAccessVehicleOutsideBusiness() {
        User user = mock(User.class);

        when(user.getAccountType())
                .thenReturn(AccountType.BUSINESS);

        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        ReflectionTestUtils.setField(
                businessAccount,
                "id",
                10L
        );

        when(businessContextService.requireUser(
                "member@example.com"
        )).thenReturn(user);

        when(businessContextService.requireBusinessAccount(user))
                .thenReturn(businessAccount);

        when(vehicleRepository
                .findByIdAndBusinessAccountIdAndArchivedFalse(
                        99L,
                        10L
                ))
                .thenReturn(Optional.empty());

        assertThrows(
                ResourceNotFoundException.class,
                () -> service.getMyVehicleById(
                        99L,
                        "member@example.com"
                )
        );
    }
}