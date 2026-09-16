package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.SubscriptionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BusinessContextServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private BusinessMemberRepository businessMemberRepository;

    @Mock
    private SubscriptionService subscriptionService;

    private BusinessContextService service;

    @BeforeEach
    void setUp() {
        service = new BusinessContextService(
                userRepository,
                businessMemberRepository,
                subscriptionService
        );

        lenient().when(subscriptionService.getEffectivePlan(any(User.class)))
                .thenAnswer(invocation ->
                        ((User) invocation.getArgument(0)).getSubscriptionPlan()
                );
    }

    @Test
    void shouldReturnUserByNormalizedEmail() {
        User user = mock(User.class);

        when(userRepository.findByEmail("test@example.com"))
                .thenReturn(Optional.of(user));

        User result =
                service.requireUser(" Test@Example.com ");

        assertSame(user, result);

        verify(userRepository)
                .findByEmail("test@example.com");
    }

    @Test
    void shouldRejectWhenUserDoesNotExist() {
        when(userRepository.findByEmail("test@example.com"))
                .thenReturn(Optional.empty());

        assertThrows(
                ResourceNotFoundException.class,
                () -> service.requireUser("test@example.com")
        );
    }

    @Test
    void shouldReturnMembershipWhenExists() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);

        BusinessMember membership =
                new BusinessMember(
                        new BusinessAccount("ABC Ekspertiz"),
                        user,
                        BusinessRole.MEMBER
                );

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(membership));

        Optional<BusinessMember> result =
                service.findMembership(user);

        assertTrue(result.isPresent());
        assertSame(membership, result.get());
    }

    @Test
    void shouldReturnTrueWhenUserIsBusinessMember() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);

        when(businessMemberRepository.existsByUserId(1L))
                .thenReturn(true);

        assertTrue(service.isBusinessMember(user));
    }

    @Test
    void shouldReturnFalseWhenUserIsNotBusinessMember() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);

        when(businessMemberRepository.existsByUserId(1L))
                .thenReturn(false);

        assertFalse(service.isBusinessMember(user));
    }

    @Test
    void shouldReturnRequiredMembership() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);

        BusinessMember membership =
                new BusinessMember(
                        new BusinessAccount("ABC Ekspertiz"),
                        user,
                        BusinessRole.MEMBER
                );

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(membership));

        BusinessMember result =
                service.requireMembership(user);

        assertSame(membership, result);
    }

    @Test
    void shouldRejectWhenMembershipDoesNotExist() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.empty());

        assertThrows(
                IllegalStateException.class,
                () -> service.requireMembership(user)
        );
    }

    @Test
    void shouldReturnBusinessAccount() {
        User user = mock(User.class);
        User owner = mock(User.class);
        when(owner.getSubscriptionPlan())
                .thenReturn(com.gorkem.vehicle_inspector.entity.SubscriptionPlan.BUSINESS);

        when(user.getId()).thenReturn(1L);

        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        BusinessMember membership =
                new BusinessMember(
                        businessAccount,
                        user,
                        BusinessRole.MEMBER
                );

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(membership));
        when(businessMemberRepository.findByBusinessAccountIdAndRole(
                null,
                BusinessRole.OWNER
        )).thenReturn(Optional.of(new BusinessMember(
                businessAccount,
                owner,
                BusinessRole.OWNER
        )));

        BusinessAccount result =
                service.requireBusinessAccount(user);

        assertSame(businessAccount, result);
    }

    @Test
    void ownerShouldPassOwnerCheck() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);
        when(user.getSubscriptionPlan())
                .thenReturn(com.gorkem.vehicle_inspector.entity.SubscriptionPlan.BUSINESS);

        BusinessMember membership =
                new BusinessMember(
                        new BusinessAccount("ABC Ekspertiz"),
                        user,
                        BusinessRole.OWNER
                );

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(membership));

        BusinessMember result =
                service.requireOwner(user);

        assertSame(membership, result);
    }

    @Test
    void memberShouldFailOwnerCheck() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(1L);

        BusinessMember membership =
                new BusinessMember(
                        new BusinessAccount("ABC Ekspertiz"),
                        user,
                        BusinessRole.MEMBER
                );

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(membership));

        assertThrows(
                IllegalStateException.class,
                () -> service.requireOwner(user)
        );
    }

    @Test
    void ownerWithoutBusinessPlanShouldFailOwnerCheck() {
        User user = mock(User.class);
        when(user.getId()).thenReturn(1L);
        when(user.getSubscriptionPlan())
                .thenReturn(com.gorkem.vehicle_inspector.entity.SubscriptionPlan.PRO);

        BusinessMember membership = new BusinessMember(
                new BusinessAccount("ABC Ekspertiz"),
                user,
                BusinessRole.OWNER
        );

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(membership));
        assertThrows(
                IllegalStateException.class,
                () -> service.requireOwner(user)
        );
    }
}
