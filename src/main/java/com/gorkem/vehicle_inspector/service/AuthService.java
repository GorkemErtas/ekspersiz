package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.ChangePasswordRequest;
import com.gorkem.vehicle_inspector.dto.request.LoginRequest;
import com.gorkem.vehicle_inspector.dto.request.RegisterRequest;
import com.gorkem.vehicle_inspector.dto.request.ResendVerificationRequest;
import com.gorkem.vehicle_inspector.dto.request.VerifyEmailRequest;
import com.gorkem.vehicle_inspector.dto.response.AuthResponse;
import com.gorkem.vehicle_inspector.dto.response.BusinessAccountResponse;
import com.gorkem.vehicle_inspector.dto.response.UserResponse;
import com.gorkem.vehicle_inspector.entity.User;
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
    private final RegistrationService registrationService;
    private final BusinessContextService businessContextService;
    private final SubscriptionService subscriptionService;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            AuthenticationManager authenticationManager,
            JwtService jwtService,
            RegistrationService registrationService,
            BusinessContextService businessContextService,
            SubscriptionService subscriptionService
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.jwtService = jwtService;
        this.registrationService = registrationService;
        this.businessContextService = businessContextService;
        this.subscriptionService = subscriptionService;
    }

    public void register(RegisterRequest request) {
        registrationService.start(request);
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
                subscriptionService.getEffectivePlan(user),
                getBusinessAccount(user)
        );
    }

    public void verifyEmail(VerifyEmailRequest request) {
        registrationService.verify(request);
    }

    public void resendVerificationCode(
            ResendVerificationRequest request
    ) {
        registrationService.resend(request);
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

        return UserMapper.toResponse(
                user,
                subscriptionService.getEffectivePlan(user),
                getBusinessAccount(user)
        );
    }

    private BusinessAccountResponse getBusinessAccount(User user) {
        return businessContextService.findMembership(user)
                .map(member -> new BusinessAccountResponse(
                        member.getBusinessAccount().getId(),
                        member.getBusinessAccount().getCompanyName(),
                        member.getRole()
                ))
                .orElse(null);
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }
}
