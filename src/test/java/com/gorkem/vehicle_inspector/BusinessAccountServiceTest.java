package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.CreateBusinessAccountRequest;
import com.gorkem.vehicle_inspector.dto.response.BusinessAccountResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.BusinessAccountRepository;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.BusinessAccountService;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BusinessAccountServiceTest {

    @Mock
    private BusinessAccountRepository businessAccountRepository;

    @Mock
    private BusinessMemberRepository businessMemberRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private VehicleRepository vehicleRepository;

    private BusinessAccountService businessAccountService;

    @BeforeEach
    void setUp() {
        businessAccountService = new BusinessAccountService(
                businessAccountRepository,
                businessMemberRepository,
                userRepository,
                vehicleRepository
        );
    }

    @Test
    void individualUserShouldCreateBusinessAccountAsOwner() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);
        when(user.getAccountType())
                .thenReturn(AccountType.INDIVIDUAL);

        when(userRepository.findByEmail("test@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.existsByUserId(1L))
                .thenReturn(false);

        when(businessAccountRepository.save(any(BusinessAccount.class)))
                .thenAnswer(invocation ->
                        invocation.getArgument(0)
                );

        when(vehicleRepository.findAllByUserId(user.getId()))
                .thenReturn(List.of());

        CreateBusinessAccountRequest request =
                new CreateBusinessAccountRequest(
                        "ABC Ekspertiz"
                );

        BusinessAccountResponse response =
                businessAccountService.create(
                        "test@example.com",
                        request
                );

        assertEquals(
                "ABC Ekspertiz",
                response.companyName()
        );

        assertEquals(
                BusinessRole.OWNER,
                response.role()
        );

        assertEquals(
                SubscriptionPlan.FREE,
                response.subscriptionPlan()
        );

        verify(user)
                .setAccountType(AccountType.BUSINESS);

        verify(userRepository).save(user);

        ArgumentCaptor<BusinessMember> memberCaptor =
                ArgumentCaptor.forClass(
                        BusinessMember.class
                );

        verify(businessMemberRepository)
                .save(memberCaptor.capture());

        BusinessMember savedMember =
                memberCaptor.getValue();

        assertSame(
                user,
                savedMember.getUser()
        );

        assertEquals(
                BusinessRole.OWNER,
                savedMember.getRole()
        );
    }

    @Test
    void userAlreadyInBusinessShouldNotCreateAnotherBusiness() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);

        when(userRepository.findByEmail("test@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.existsByUserId(1L))
                .thenReturn(true);

        CreateBusinessAccountRequest request =
                new CreateBusinessAccountRequest(
                        "ABC Ekspertiz"
                );

        assertThrows(
                IllegalStateException.class,
                () -> businessAccountService.create(
                        "test@example.com",
                        request
                )
        );

        verify(
                businessAccountRepository,
                never()
        ).save(any());

        verify(
                businessMemberRepository,
                never()
        ).save(any());

        verify(
                userRepository,
                never()
        ).save(any());
    }

    @Test
    void nonIndividualUserWithoutMembershipShouldNotCreateBusiness() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);
        when(user.getAccountType())
                .thenReturn(AccountType.BUSINESS);

        when(userRepository.findByEmail("test@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.existsByUserId(1L))
                .thenReturn(false);

        CreateBusinessAccountRequest request =
                new CreateBusinessAccountRequest(
                        "ABC Ekspertiz"
                );

        assertThrows(
                IllegalStateException.class,
                () -> businessAccountService.create(
                        "test@example.com",
                        request
                )
        );

        verify(
                businessAccountRepository,
                never()
        ).save(any());
    }

    @Test
    void existingVehiclesShouldMoveToBusinessAccount() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);
        when(user.getAccountType())
                .thenReturn(AccountType.INDIVIDUAL);

        when(userRepository.findByEmail("owner@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.existsByUserId(1L))
                .thenReturn(false);

        Vehicle vehicle = new Vehicle(
                "35ABC123",
                "BMW",
                "320i",
                2022,
                30000,
                user
        );

        when(vehicleRepository.findAllByUserId(1L))
                .thenReturn(List.of(vehicle));

        when(businessAccountRepository.save(
                any(BusinessAccount.class)
        )).thenAnswer(invocation ->
                invocation.getArgument(0)
        );

        CreateBusinessAccountRequest request =
                new CreateBusinessAccountRequest(
                        "ABC Ekspertiz"
                );

        businessAccountService.create(
                "owner@example.com",
                request
        );

        assertNull(vehicle.getUser());
        assertNotNull(vehicle.getBusinessAccount());
        assertEquals(
                "ABC Ekspertiz",
                vehicle.getBusinessAccount()
                        .getCompanyName()
        );

        verify(vehicleRepository)
                .findAllByUserId(1L);

        verify(user)
                .setAccountType(AccountType.BUSINESS);
    }
}