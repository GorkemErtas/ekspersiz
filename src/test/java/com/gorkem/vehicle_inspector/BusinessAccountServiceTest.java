package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.CreateBusinessAccountRequest;
import com.gorkem.vehicle_inspector.dto.response.BusinessAccountResponse;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.BusinessAccountRepository;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.BusinessAccountService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

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

    private BusinessAccountService businessAccountService;

    @BeforeEach
    void setUp() {
        businessAccountService =
                new BusinessAccountService(
                        businessAccountRepository,
                        businessMemberRepository,
                        userRepository
                );
    }

    @Test
    void businessPlanUserShouldCreateBusinessAccountAsOwner() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);
        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.BUSINESS);

        when(userRepository.findByEmail("test@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.existsByUserId(1L))
                .thenReturn(false);

        when(businessAccountRepository.save(
                any(BusinessAccount.class)
        )).thenAnswer(invocation ->
                invocation.getArgument(0)
        );

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

        assertEquals(
                "ABC Ekspertiz",
                savedMember
                        .getBusinessAccount()
                        .getCompanyName()
        );

        verify(userRepository, never())
                .save(any(User.class));
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
    }

    @Test
    void nonBusinessPlanUserShouldNotCreateBusinessAccount() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);
        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.FREE);

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

        verify(
                businessMemberRepository,
                never()
        ).save(any());
    }

    @Test
    void companyNameShouldBeTrimmedWhenCreatingBusinessAccount() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);
        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.BUSINESS);

        when(userRepository.findByEmail("owner@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.existsByUserId(1L))
                .thenReturn(false);

        when(businessAccountRepository.save(
                any(BusinessAccount.class)
        )).thenAnswer(invocation ->
                invocation.getArgument(0)
        );

        CreateBusinessAccountRequest request =
                new CreateBusinessAccountRequest(
                        "  ABC Ekspertiz  "
                );

        BusinessAccountResponse response =
                businessAccountService.create(
                        "owner@example.com",
                        request
                );

        assertEquals(
                "ABC Ekspertiz",
                response.companyName()
        );
    }
}