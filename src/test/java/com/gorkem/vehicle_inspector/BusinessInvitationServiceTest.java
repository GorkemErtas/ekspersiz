package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.CreateBusinessInvitationRequest;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.BusinessInvitationRepository;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.BusinessInvitationService;
import com.gorkem.vehicle_inspector.service.VerificationCodeService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.util.ReflectionTestUtils;
import org.mockito.ArgumentCaptor;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BusinessInvitationServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private BusinessMemberRepository businessMemberRepository;

    @Mock
    private BusinessInvitationRepository businessInvitationRepository;

    @Mock
    private VerificationCodeService verificationCodeService;

    @Mock
    private JavaMailSender mailSender;

    private BusinessInvitationService service;

    @BeforeEach
    void setUp() {
        service = new BusinessInvitationService(
                userRepository,
                businessMemberRepository,
                businessInvitationRepository,
                verificationCodeService,
                mailSender
        );

        ReflectionTestUtils.setField(
                service,
                "mailFrom",
                "test@example.com"
        );
    }

    @Test
    void ownerShouldInviteUserWithoutBusinessMembership() {
        User owner = mock(User.class);
        User invitedUser = mock(User.class);
        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        BusinessMember ownerMembership =
                new BusinessMember(
                        businessAccount,
                        owner,
                        BusinessRole.OWNER
                );

        when(owner.getId()).thenReturn(1L);
        when(owner.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.BUSINESS);

        when(invitedUser.getId()).thenReturn(2L);
        when(invitedUser.getEmail())
                .thenReturn("worker@example.com");
        when(invitedUser.getFullName())
                .thenReturn("Ahmet");

        when(userRepository.findByEmail("owner@example.com"))
                .thenReturn(Optional.of(owner));

        when(userRepository.findByEmail("worker@example.com"))
                .thenReturn(Optional.of(invitedUser));

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(ownerMembership));

        when(businessMemberRepository.existsByUserId(2L))
                .thenReturn(false);

        when(verificationCodeService.generate())
                .thenReturn("123456");

        when(verificationCodeService.hash("123456"))
                .thenReturn("hashed-code");

        CreateBusinessInvitationRequest request =
                new CreateBusinessInvitationRequest(
                        "worker@example.com"
                );

        service.invite(
                "owner@example.com",
                request
        );

        verify(businessInvitationRepository)
                .save(any(BusinessInvitation.class));

        verify(mailSender).send(any(
                org.springframework.mail.SimpleMailMessage.class
        ));
    }

    @Test
    void ownerWithoutBusinessPlanShouldNotInviteUser() {
        User owner = mock(User.class);
        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");
        BusinessMember ownerMembership =
                new BusinessMember(
                        businessAccount,
                        owner,
                        BusinessRole.OWNER
                );

        when(owner.getId()).thenReturn(1L);
        when(owner.getSubscriptionPlan()).thenReturn(SubscriptionPlan.PRO);
        when(userRepository.findByEmail("owner@example.com"))
                .thenReturn(Optional.of(owner));
        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(ownerMembership));

        CreateBusinessInvitationRequest request =
                new CreateBusinessInvitationRequest("worker@example.com");

        assertThrows(
                IllegalStateException.class,
                () -> service.invite("owner@example.com", request)
        );

        verify(businessInvitationRepository, never()).save(any());
        verifyNoInteractions(mailSender);
    }

    @Test
    void memberShouldNotInviteAnotherUser() {
        User memberUser = mock(User.class);

        when(memberUser.getId()).thenReturn(1L);

        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        BusinessMember membership =
                new BusinessMember(
                        businessAccount,
                        memberUser,
                        BusinessRole.MEMBER
                );

        when(userRepository.findByEmail("member@example.com"))
                .thenReturn(Optional.of(memberUser));

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(membership));

        CreateBusinessInvitationRequest request =
                new CreateBusinessInvitationRequest(
                        "worker@example.com"
                );

        assertThrows(
                IllegalStateException.class,
                () -> service.invite(
                        "member@example.com",
                        request
                )
        );

        verify(
                businessInvitationRepository,
                never()
        ).save(any());

        verify(
                mailSender,
                never()
        ).send(any(
                org.springframework.mail.SimpleMailMessage.class
        ));
    }

    @Test
    void userShouldAcceptValidInvitation() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(2L);

        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        BusinessInvitation invitation =
                new BusinessInvitation(
                        businessAccount,
                        user,
                        "hashed-code"
                );

        when(userRepository.findByEmail("worker@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.existsByUserId(2L))
                .thenReturn(false);

        when(businessInvitationRepository.findByUserId(2L))
                .thenReturn(Optional.of(invitation));

        when(verificationCodeService.matches(
                "123456",
                "hashed-code"
        )).thenReturn(true);

        service.accept(
                "worker@example.com",
                "123456"
        );

        ArgumentCaptor<BusinessMember> memberCaptor =
                ArgumentCaptor.forClass(
                        BusinessMember.class
                );

        verify(businessMemberRepository)
                .save(memberCaptor.capture());

        BusinessMember savedMember =
                memberCaptor.getValue();

        assertSame(user, savedMember.getUser());
        assertSame(
                businessAccount,
                savedMember.getBusinessAccount()
        );
        assertEquals(
                BusinessRole.MEMBER,
                savedMember.getRole()
        );

        verify(businessInvitationRepository)
                .delete(invitation);
    }

    @Test
    void wrongInvitationCodeShouldBeRejected() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(2L);

        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        BusinessInvitation invitation =
                new BusinessInvitation(
                        businessAccount,
                        user,
                        "hashed-code"
                );

        when(userRepository.findByEmail("worker@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.existsByUserId(2L))
                .thenReturn(false);

        when(businessInvitationRepository.findByUserId(2L))
                .thenReturn(Optional.of(invitation));

        when(verificationCodeService.matches(
                "999999",
                "hashed-code"
        )).thenReturn(false);

        assertThrows(
                IllegalArgumentException.class,
                () -> service.accept(
                        "worker@example.com",
                        "999999"
                )
        );

        verify(
                businessMemberRepository,
                never()
        ).save(any());

        verify(
                userRepository,
                never()
        ).save(any());

        verify(
                businessInvitationRepository,
                never()
        ).delete(invitation);
    }

    @Test
    void expiredInvitationShouldBeRejectedAndDeleted() {
        User user = mock(User.class);

        when(user.getId()).thenReturn(2L);

        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        BusinessInvitation invitation =
                new BusinessInvitation(
                        businessAccount,
                        user,
                        "hashed-code"
                );

        ReflectionTestUtils.setField(
                invitation,
                "expiresAt",
                LocalDateTime.now().minusMinutes(1)
        );

        when(userRepository.findByEmail("worker@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.existsByUserId(2L))
                .thenReturn(false);

        when(businessInvitationRepository.findByUserId(2L))
                .thenReturn(Optional.of(invitation));

        assertThrows(
                IllegalArgumentException.class,
                () -> service.accept(
                        "worker@example.com",
                        "123456"
                )
        );

        verify(businessInvitationRepository)
                .delete(invitation);

        verify(
                businessMemberRepository,
                never()
        ).save(any());
    }
}
