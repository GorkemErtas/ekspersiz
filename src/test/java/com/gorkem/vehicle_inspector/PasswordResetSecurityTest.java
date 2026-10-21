package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.ResetPasswordRequest;
import com.gorkem.vehicle_inspector.entity.PasswordResetCode;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.PasswordResetCodeRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.*;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.*;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PasswordResetSecurityTest {
    @Test
    void successfulResetLocksIdentityRevokesSessionsAndConsumesCode() {
        var users = mock(UserRepository.class);
        var codes = mock(PasswordResetCodeRepository.class);
        var verification = mock(VerificationCodeService.class);
        var encoder = mock(PasswordEncoder.class);
        Clock clock = Clock.fixed(Instant.parse("2026-10-21T10:00:00Z"), ZoneOffset.UTC);
        User user = new User("Owner", "owner@example.com", "old-hash");
        ReflectionTestUtils.setField(user, "id", 1L);
        var code = new PasswordResetCode(user, "code-hash", LocalDateTime.now(clock).plusMinutes(5),
                LocalDateTime.now(clock));
        when(users.findByEmailForUpdate(user.getEmail())).thenReturn(Optional.of(user));
        when(codes.findByUserId(1L)).thenReturn(Optional.of(code));
        when(verification.matches("123456", "code-hash")).thenReturn(true);
        when(encoder.encode("new-password")).thenReturn("new-hash");
        var service = new PasswordResetService(users, codes, verification, encoder, mock(EmailService.class), clock);
        var request = new ResetPasswordRequest();
        request.setEmail(" OWNER@EXAMPLE.COM "); request.setCode("123456");
        request.setNewPassword("new-password"); request.setConfirmNewPassword("new-password");
        service.resetPassword(request);
        assertEquals(1, user.getAuthVersion());
        assertEquals("new-hash", user.getPassword());
        var order = inOrder(users, codes);
        order.verify(users).findByEmailForUpdate(user.getEmail());
        order.verify(codes).findByUserId(1L);
        order.verify(users).save(user);
        order.verify(codes).delete(code);
    }

    @Test
    void incorrectCodeDoesNotChangeCredentialsOrConsumeValidCode() {
        var users = mock(UserRepository.class);
        var codes = mock(PasswordResetCodeRepository.class);
        var verification = mock(VerificationCodeService.class);
        var encoder = mock(PasswordEncoder.class);
        User user = new User("Owner", "owner@example.com", "old-hash");
        ReflectionTestUtils.setField(user, "id", 1L);
        var code = new PasswordResetCode(user, "code-hash", LocalDateTime.now().plusMinutes(5), LocalDateTime.now());
        when(users.findByEmailForUpdate(user.getEmail())).thenReturn(Optional.of(user));
        when(codes.findByUserId(1L)).thenReturn(Optional.of(code));
        var request = new ResetPasswordRequest(); request.setEmail(user.getEmail()); request.setCode("000000");
        var service = new PasswordResetService(users, codes, verification, encoder, mock(EmailService.class), Clock.systemDefaultZone());
        assertThrows(IllegalArgumentException.class, () -> service.resetPassword(request));
        assertEquals(0, user.getAuthVersion());
        verify(users, never()).save(any()); verify(codes, never()).delete(any()); verifyNoInteractions(encoder);
    }
}
