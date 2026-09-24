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

    public AuthController(
            AuthService authService,
            PasswordResetService passwordResetService,
            AccountDeletionService accountDeletionService
    ) {
        this.authService = authService;
        this.passwordResetService = passwordResetService;
        this.accountDeletionService = accountDeletionService;
    }

    @PostMapping("/register")
    public ResponseEntity<Void> register(
            @Valid @RequestBody RegisterRequest request
    ) {
        authService.register(request);

        return ResponseEntity
                .status(HttpStatus.ACCEPTED)
                .build();
    }

    @PostMapping("/verify-email")
    public ResponseEntity<Void> verifyEmail(
            @Valid @RequestBody VerifyEmailRequest request
    ) {
        authService.verifyEmail(request);

        return ResponseEntity.noContent().build();
    }

    @PostMapping("/resend-verification")
    public ResponseEntity<Void> resendVerification(
            @Valid @RequestBody ResendVerificationRequest request
    ) {
        authService.resendVerificationCode(request);

        return ResponseEntity.noContent().build();
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(
            @Valid @RequestBody LoginRequest request
    ) {
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
        passwordResetService.requestReset(request);

        return ResponseEntity.accepted().build();
    }

    @PostMapping("/reset-password")
    public ResponseEntity<Void> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request
    ) {
        passwordResetService.resetPassword(request);

        return ResponseEntity.noContent().build();
    }

    @PostMapping("/change-password")
    public ResponseEntity<Void> changePassword(
            @Valid @RequestBody ChangePasswordRequest request,
            Authentication authentication
    ) {
        authService.changePassword(
                authentication.getName(),
                request
        );

        return ResponseEntity.noContent().build();
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
