package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.ChangePasswordRequest;
import com.gorkem.vehicle_inspector.dto.request.LoginRequest;
import com.gorkem.vehicle_inspector.dto.request.RegisterRequest;
import com.gorkem.vehicle_inspector.dto.request.ResendVerificationRequest;
import com.gorkem.vehicle_inspector.dto.request.VerifyEmailRequest;
import com.gorkem.vehicle_inspector.dto.response.AuthResponse;
import com.gorkem.vehicle_inspector.dto.response.UserResponse;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.DuplicateResourceException;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.mapper.UserMapper;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.security.JwtService;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;
    private final EmailVerificationService emailVerificationService;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            AuthenticationManager authenticationManager,
            JwtService jwtService,
            EmailVerificationService emailVerificationService
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.jwtService = jwtService;
        this.emailVerificationService = emailVerificationService;
    }

    public UserResponse register(RegisterRequest request) {
        String normalizedEmail = normalizeEmail(request.getEmail());

        if (userRepository.existsByEmail(normalizedEmail)) {
            throw new DuplicateResourceException(
                    "Bu e-posta adresi zaten kullanılıyor: "
                            + normalizedEmail
            );
        }

        User user = new User(
                request.getFullName().trim(),
                normalizedEmail,
                passwordEncoder.encode(request.getPassword())
        );

        User savedUser = userRepository.save(user);

        emailVerificationService.createAndSendVerificationCode(
                savedUser
        );

        return UserMapper.toResponse(savedUser);
    }

    public AuthResponse login(LoginRequest request) {
        String normalizedEmail = normalizeEmail(request.getEmail());

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        normalizedEmail,
                        request.getPassword()
                )
        );

        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Kullanıcı bulunamadı."
                        )
                );

        if (!user.isEmailVerified()) {
            throw new IllegalStateException(
                    "E-posta adresinizi doğrulamadan giriş yapamazsınız."
            );
        }

        String token = jwtService.generateToken(user);

        return new AuthResponse(
                token,
                "Bearer",
                jwtService.getExpiration(),
                user.getId(),
                user.getFullName(),
                user.getEmail(),
                user.getSubscriptionPlan()
        );
    }

    public void verifyEmail(VerifyEmailRequest request) {
        String normalizedEmail = normalizeEmail(request.getEmail());

        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Kullanıcı bulunamadı."
                        )
                );

        if (user.isEmailVerified()) {
            return;
        }

        if (user.getEmailVerificationCodeHash() == null
                || user.isEmailVerificationCodeExpired()) {
            throw new IllegalArgumentException(
                    "Doğrulama kodunun süresi dolmuş. "
                            + "Lütfen yeni kod isteyin."
            );
        }

        if (!passwordEncoder.matches(
                request.getCode(),
                user.getEmailVerificationCodeHash()
        )) {
            throw new IllegalArgumentException(
                    "Doğrulama kodu hatalı."
            );
        }

        user.markEmailVerified();
        userRepository.save(user);
    }

    public void resendVerificationCode(
            ResendVerificationRequest request
    ) {
        String normalizedEmail = normalizeEmail(request.getEmail());

        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Kullanıcı bulunamadı."
                        )
                );

        if (user.isEmailVerified()) {
            throw new IllegalArgumentException(
                    "Bu e-posta adresi zaten doğrulanmış."
            );
        }

        emailVerificationService
                .createAndSendVerificationCode(user);
    }

    public void changePassword(
            String email,
            ChangePasswordRequest request
    ) {
        String normalizedEmail = normalizeEmail(email);

        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Kullanıcı bulunamadı."
                        )
                );

        if (!passwordEncoder.matches(
                request.getCurrentPassword(),
                user.getPassword()
        )) {
            throw new IllegalArgumentException(
                    "Mevcut şifre hatalı."
            );
        }

        if (!request.getNewPassword().equals(
                request.getConfirmNewPassword()
        )) {
            throw new IllegalArgumentException(
                    "Yeni şifreler eşleşmiyor."
            );
        }

        if (passwordEncoder.matches(
                request.getNewPassword(),
                user.getPassword()
        )) {
            throw new IllegalArgumentException(
                    "Yeni şifre mevcut şifreden farklı olmalıdır."
            );
        }

        user.setPassword(
                passwordEncoder.encode(request.getNewPassword())
        );

        userRepository.save(user);
    }

    public UserResponse getCurrentUser(String email) {
        String normalizedEmail = normalizeEmail(email);

        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Kullanıcı bulunamadı."
                        )
                );

        return UserMapper.toResponse(user);
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }
}