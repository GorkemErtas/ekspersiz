package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.response.VehicleResponse;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
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
    void personalUserShouldSeeOwnVehicles() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);

        when(businessContextService.requireUser(
                "user@example.com"
        )).thenReturn(user);

        when(businessContextService.isBusinessMember(user))
                .thenReturn(false);

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

        when(businessContextService.isBusinessMember(user))
                .thenReturn(true);

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
    void businessMemberShouldNotAccessVehicleOutsideBusiness() {
        User user = mock(User.class);

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

        when(businessContextService.isBusinessMember(user))
                .thenReturn(true);

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

    @Test
    void personalUserShouldUsePersonalVehicleLimitWhenCreatingVehicle() {
        User user = mock(User.class);

        when(businessContextService.requireUser(
                "user@example.com"
        )).thenReturn(user);

        when(businessContextService.isBusinessMember(user))
                .thenReturn(false);

        when(user.getId()).thenReturn(1L);

        when(vehicleRepository.existsByPlate("35ABC123"))
                .thenReturn(false);

        when(vehicleRepository
                .countByUserIdAndArchivedFalse(1L))
                .thenReturn(0L);

        when(vehicleRepository.save(any(Vehicle.class)))
                .thenAnswer(invocation ->
                        invocation.getArgument(0)
                );

        var request =
                new com.gorkem.vehicle_inspector.dto.request.CreateVehicleRequest();

        request.setPlate("35ABC123");
        request.setBrand("BMW");
        request.setModel("320i");
        request.setModelYear(2022);
        request.setMileage(30000);

        service.createVehicle(
                request,
                "user@example.com"
        );

        verify(subscriptionService)
                .validateVehicleLimit(user);

        verify(
                subscriptionService,
                never()
        ).validateBusinessVehicleLimit(
                any(BusinessAccount.class)
        );
    }

    @Test
    void businessMemberShouldUseBusinessVehicleLimitWhenCreatingVehicle() {
        User user = mock(User.class);

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

        when(businessContextService.isBusinessMember(user))
                .thenReturn(true);

        when(businessContextService.requireBusinessAccount(user))
                .thenReturn(businessAccount);

        when(vehicleRepository.existsByPlate("35ABC123"))
                .thenReturn(false);

        when(vehicleRepository
                .countByBusinessAccountIdAndArchivedFalse(10L))
                .thenReturn(20L);

        when(vehicleRepository.save(any(Vehicle.class)))
                .thenAnswer(invocation ->
                        invocation.getArgument(0)
                );

        var request =
                new com.gorkem.vehicle_inspector.dto.request.CreateVehicleRequest();

        request.setPlate("35ABC123");
        request.setBrand("BMW");
        request.setModel("320i");
        request.setModelYear(2022);
        request.setMileage(30000);

        service.createVehicle(
                request,
                "member@example.com"
        );

        verify(subscriptionService)
                .validateBusinessVehicleLimit(
                        businessAccount
                );

        verify(
                subscriptionService,
                never()
        ).validateVehicleLimit(user);
    }
}