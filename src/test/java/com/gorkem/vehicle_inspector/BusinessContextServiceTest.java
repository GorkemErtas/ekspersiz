package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
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

    private BusinessContextService service;

    @BeforeEach
    void setUp() {
        service = new BusinessContextService(
                userRepository,
                businessMemberRepository
        );
    }

    @Test
    void shouldReturnBusinessMembership() {
        User user = mock(User.class);

        when(user.getAccountType())
                .thenReturn(AccountType.BUSINESS);

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

        BusinessMember result =
                service.requireMembership(user);

        assertSame(membership, result);
    }

    @Test
    void individualUserShouldNotHaveBusinessMembership() {
        User user = mock(User.class);

        when(user.getAccountType())
                .thenReturn(AccountType.INDIVIDUAL);

        assertThrows(
                IllegalStateException.class,
                () -> service.requireMembership(user)
        );

        verify(
                businessMemberRepository,
                never()
        ).findByUserId(anyLong());
    }

    @Test
    void businessUserWithoutMembershipShouldBeRejected() {
        User user = mock(User.class);

        when(user.getAccountType())
                .thenReturn(AccountType.BUSINESS);

        when(user.getId()).thenReturn(1L);

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.empty());

        assertThrows(
                IllegalStateException.class,
                () -> service.requireMembership(user)
        );
    }

    @Test
    void ownerShouldPassOwnerCheck() {
        User user = mock(User.class);

        when(user.getAccountType())
                .thenReturn(AccountType.BUSINESS);

        when(user.getId()).thenReturn(1L);

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

        when(user.getAccountType())
                .thenReturn(AccountType.BUSINESS);

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
}