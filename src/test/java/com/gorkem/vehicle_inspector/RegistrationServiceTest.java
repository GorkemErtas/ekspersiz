package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.RegisterRequest;
import com.gorkem.vehicle_inspector.dto.request.VerifyEmailRequest;
import com.gorkem.vehicle_inspector.entity.PendingRegistration;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.DuplicateResourceException;
import com.gorkem.vehicle_inspector.repository.BusinessInvitationRepository;
import com.gorkem.vehicle_inspector.repository.PendingRegistrationRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.EmailService;
import com.gorkem.vehicle_inspector.service.RegistrationService;
import com.gorkem.vehicle_inspector.service.VerificationCodeService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RegistrationServiceTest {

    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-09-16T08:00:00Z"),
            ZoneId.of("Europe/Istanbul")
    );
    private static final LocalDateTime NOW = LocalDateTime.now(CLOCK);

    @Mock
    private UserRepository userRepository;

    @Mock
    private PendingRegistrationRepository pendingRegistrationRepository;

    @Mock
    private BusinessInvitationRepository businessInvitationRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private VerificationCodeService verificationCodeService;

    @Mock
    private EmailService emailService;

    private RegistrationService service;

    @BeforeEach
    void setUp() {
        service = new RegistrationService(
                userRepository,
                pendingRegistrationRepository,
                businessInvitationRepository,
                passwordEncoder,
                verificationCodeService,
                emailService,
                CLOCK
        );
    }

    @Test
    void registrationShouldCreatePendingRecordWithoutCreatingUser() {
        when(userRepository.findByEmail("new@example.com"))
                .thenReturn(Optional.empty());
        when(pendingRegistrationRepository.findByEmail("new@example.com"))
                .thenReturn(Optional.empty());
        when(passwordEncoder.encode("password"))
                .thenReturn("password-hash");
        when(verificationCodeService.generate()).thenReturn("123456");
        when(verificationCodeService.hash("123456"))
                .thenReturn("code-hash");

        service.start(registerRequest(" New@Example.com "));

        ArgumentCaptor<PendingRegistration> pendingCaptor =
                ArgumentCaptor.forClass(PendingRegistration.class);
        verify(pendingRegistrationRepository).save(pendingCaptor.capture());

        PendingRegistration pending = pendingCaptor.getValue();
        assertEquals("Test User", pending.getFullName());
        assertEquals("new@example.com", pending.getEmail());
        assertEquals("password-hash", pending.getPasswordHash());
        assertEquals("code-hash", pending.getVerificationCodeHash());
        assertEquals(NOW.plusMinutes(5), pending.getVerificationCodeExpiresAt());
        verify(userRepository, never()).save(any(User.class));
        verify(emailService).send(
                eq("new@example.com"),
                eq("EksperSiz - E-posta Doğrulama Kodu"),
                contains("123456")
        );
    }

    @Test
    void validVerificationShouldCreateVerifiedUserAndDeletePendingRecord() {
        PendingRegistration pending = mock(PendingRegistration.class);
        when(pending.getEmail()).thenReturn("new@example.com");
        when(pending.getPasswordHash()).thenReturn("password-hash");
        when(pending.getVerificationCodeHash()).thenReturn("code-hash");
        when(pending.isVerificationCodeExpired(NOW)).thenReturn(false);
        when(pendingRegistrationRepository.findByEmailForUpdate("new@example.com"))
                .thenReturn(Optional.of(pending));
        when(verificationCodeService.matches("123456", "code-hash"))
                .thenReturn(true);
        when(userRepository.existsByEmail("new@example.com"))
                .thenReturn(false);

        VerifyEmailRequest request = new VerifyEmailRequest();
        request.setEmail(" NEW@EXAMPLE.COM ");
        request.setCode("123456");

        service.verify(request);

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        assertEquals("new@example.com", userCaptor.getValue().getEmail());
        assertEquals("password-hash", userCaptor.getValue().getPassword());
        assertTrue(userCaptor.getValue().isEmailVerified());
        verify(pendingRegistrationRepository).delete(pending);
    }

    @Test
    void repeatedRegistrationShouldReplacePendingDetailsWithoutCreatingUser() {
        PendingRegistration pending = mock(PendingRegistration.class);
        when(userRepository.findByEmail("new@example.com"))
                .thenReturn(Optional.empty());
        when(pendingRegistrationRepository.findByEmail("new@example.com"))
                .thenReturn(Optional.of(pending));
        when(passwordEncoder.encode("password"))
                .thenReturn("new-password-hash");
        when(verificationCodeService.generate()).thenReturn("654321");
        when(verificationCodeService.hash("654321"))
                .thenReturn("new-code-hash");
        when(pending.getEmail()).thenReturn("new@example.com");

        service.start(registerRequest("new@example.com"));

        verify(pending).replaceRegistration(
                "Test User",
                "new-password-hash",
                "new-code-hash",
                NOW,
                NOW.plusMinutes(5)
        );
        verify(pendingRegistrationRepository).save(pending);
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void verifiedEmailShouldNotRegisterAgain() {
        User user = mock(User.class);
        when(user.isEmailVerified()).thenReturn(true);
        when(userRepository.findByEmail("existing@example.com"))
                .thenReturn(Optional.of(user));

        assertThrows(
                DuplicateResourceException.class,
                () -> service.start(registerRequest("existing@example.com"))
        );

        verifyNoInteractions(pendingRegistrationRepository, emailService);
    }

    @Test
    void oldUnverifiedUserShouldBeReplacedByPendingRegistration() {
        User legacyUser = mock(User.class);
        when(legacyUser.isEmailVerified()).thenReturn(false);
        when(legacyUser.getId()).thenReturn(9L);
        when(userRepository.findByEmail("legacy@example.com"))
                .thenReturn(Optional.of(legacyUser));
        when(pendingRegistrationRepository.findByEmail("legacy@example.com"))
                .thenReturn(Optional.empty());
        when(passwordEncoder.encode("password")).thenReturn("password-hash");
        when(verificationCodeService.generate()).thenReturn("123456");
        when(verificationCodeService.hash("123456")).thenReturn("code-hash");

        service.start(registerRequest("legacy@example.com"));

        verify(businessInvitationRepository).deleteByUserId(9L);
        verify(userRepository).delete(legacyUser);
        verify(userRepository).flush();
        verify(pendingRegistrationRepository).save(any(PendingRegistration.class));
    }

    private RegisterRequest registerRequest(String email) {
        RegisterRequest request = new RegisterRequest();
        request.setFullName(" Test User ");
        request.setEmail(email);
        request.setPassword("password");
        return request;
    }
}
