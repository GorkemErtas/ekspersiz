package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.request.ChangePasswordRequest;
import com.gorkem.vehicle_inspector.dto.request.LoginRequest;
import com.gorkem.vehicle_inspector.dto.request.RegisterRequest;
import com.gorkem.vehicle_inspector.dto.request.ResendVerificationRequest;
import com.gorkem.vehicle_inspector.dto.request.VerifyEmailRequest;
import com.gorkem.vehicle_inspector.dto.response.AuthResponse;
import com.gorkem.vehicle_inspector.dto.response.UserResponse;
import com.gorkem.vehicle_inspector.service.AuthService;
import com.gorkem.vehicle_inspector.dto.request.ForgotPasswordRequest;
import com.gorkem.vehicle_inspector.dto.request.ResetPasswordRequest;
import com.gorkem.vehicle_inspector.service.PasswordResetService;
import com.gorkem.vehicle_inspector.dto.request.GoogleLoginRequest;
import com.gorkem.vehicle_inspector.service.AccountDeletionService;
import com.gorkem.vehicle_inspector.security.RequestRateLimiter;
import static com.gorkem.vehicle_inspector.security.RequestRateLimiter.Action.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;

    private final PasswordResetService passwordResetService;

    private final AccountDeletionService accountDeletionService;
    private final RequestRateLimiter rateLimiter;

    public AuthController(
            AuthService authService,
            PasswordResetService passwordResetService,
            AccountDeletionService accountDeletionService,
            RequestRateLimiter rateLimiter
    ) {
        this.authService = authService;
        this.passwordResetService = passwordResetService;
        this.accountDeletionService = accountDeletionService;
        this.rateLimiter = rateLimiter;
    }

    @PostMapping("/register")
    public ResponseEntity<Void> register(
            @Valid @RequestBody RegisterRequest request
    ) {
        rateLimiter.check(VERIFICATION_SEND, request.getEmail());
        authService.register(request);

        return ResponseEntity
                .status(HttpStatus.ACCEPTED)
                .build();
    }

    @PostMapping("/verify-email")
    public ResponseEntity<Void> verifyEmail(
            @Valid @RequestBody VerifyEmailRequest request
    ) {
        rateLimiter.check(VERIFICATION_CHECK, request.getEmail());
        authService.verifyEmail(request);

        return ResponseEntity.noContent().build();
    }

    @PostMapping("/resend-verification")
    public ResponseEntity<Void> resendVerification(
            @Valid @RequestBody ResendVerificationRequest request
    ) {
        rateLimiter.check(VERIFICATION_SEND, request.getEmail());
        authService.resendVerificationCode(request);

        return ResponseEntity.noContent().build();
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(
            @Valid @RequestBody LoginRequest request
    ) {
        rateLimiter.check(LOGIN, request.getEmail());
        return ResponseEntity.ok(
                authService.login(request)
        );
    }

    @PostMapping("/google")
    public ResponseEntity<AuthResponse> googleLogin(
            @Valid @RequestBody GoogleLoginRequest request
    ) {
        return ResponseEntity.ok(
                authService.googleLogin(request)
        );
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<Void> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request
    ) {
        rateLimiter.check(RESET_SEND, request.getEmail());
        passwordResetService.requestReset(request);

        return ResponseEntity.accepted().build();
    }

    @PostMapping("/reset-password")
    public ResponseEntity<Void> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request
    ) {
        rateLimiter.check(RESET_CHECK, request.getEmail());
        passwordResetService.resetPassword(request);

        return ResponseEntity.noContent().build();
    }

    @PostMapping("/change-password")
    public ResponseEntity<Void> changePassword(
            @Valid @RequestBody ChangePasswordRequest request,
            Authentication authentication
    ) {
        rateLimiter.check(PASSWORD_CHANGE, authentication.getName());
        String token = authService.changePassword(
                authentication.getName(),
                request
        );

        return ResponseEntity.noContent().header("Authorization", "Bearer " + token).build();
    }

    @GetMapping("/me")
    public ResponseEntity<UserResponse> getCurrentUser(
            Authentication authentication
    ) {
        UserResponse response =
                authService.getCurrentUser(authentication.getName());

        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/account")
    public ResponseEntity<Void> deleteAccount(
            Authentication authentication
    ) {
        accountDeletionService.deleteAccount(
                authentication.getName()
        );

        return ResponseEntity.noContent().build();
    }
}
