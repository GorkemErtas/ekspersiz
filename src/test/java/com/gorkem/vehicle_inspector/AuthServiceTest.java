package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.LoginRequest;
import com.gorkem.vehicle_inspector.dto.response.AuthResponse;
import com.gorkem.vehicle_inspector.dto.response.UserResponse;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.security.JwtService;
import com.gorkem.vehicle_inspector.service.AuthService;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.RegistrationService;
import com.gorkem.vehicle_inspector.service.SubscriptionService;
import com.gorkem.vehicle_inspector.service.GoogleAuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.lenient;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private AuthenticationManager authenticationManager;

    @Mock
    private JwtService jwtService;

    @Mock
    private RegistrationService registrationService;

    @Mock
    private BusinessContextService businessContextService;

    @Mock
    private SubscriptionService subscriptionService;

    @Mock
    private GoogleAuthService googleAuthService;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(
                userRepository,
                passwordEncoder,
                authenticationManager,
                jwtService,
                registrationService,
                businessContextService,
                subscriptionService,
                googleAuthService
        );

        lenient().when(subscriptionService.getEffectivePlan(any(User.class)))
                .thenAnswer(invocation ->
                        ((User) invocation.getArgument(0)).getSubscriptionPlan()
                );
    }

    @Test
    void currentUserShouldIncludeBusinessMembershipContext() {
        User user = mockUser(7L, SubscriptionPlan.PLUS);
        BusinessAccount businessAccount = org.mockito.Mockito.mock(BusinessAccount.class);
        when(businessAccount.getId()).thenReturn(11L);
        when(businessAccount.getCompanyName()).thenReturn("ABC Ekspertiz");
        BusinessMember membership = new BusinessMember(
                businessAccount,
                user,
                BusinessRole.MEMBER
        );

        when(userRepository.findByEmail("member@example.com"))
                .thenReturn(Optional.of(user));
        when(businessContextService.findMembership(user))
                .thenReturn(Optional.of(membership));

        UserResponse response = authService.getCurrentUser(" MEMBER@EXAMPLE.COM ");

        assertNotNull(response.getBusinessAccount());
        assertEquals(11L, response.getBusinessAccount().id());
        assertEquals("ABC Ekspertiz", response.getBusinessAccount().companyName());
        assertEquals(BusinessRole.MEMBER, response.getBusinessAccount().role());
        assertEquals(SubscriptionPlan.PLUS, response.getSubscriptionPlan());
    }

    @Test
    void loginShouldReturnNullBusinessContextForPersonalUser() {
        User user = mockUser(3L, SubscriptionPlan.FREE);
        when(user.isEmailVerified()).thenReturn(true);
        when(userRepository.findByEmail("personal@example.com"))
                .thenReturn(Optional.of(user));
        when(jwtService.generateToken(user)).thenReturn("token");
        when(jwtService.getExpiration()).thenReturn(86_400_000L);
        when(businessContextService.findMembership(user))
                .thenReturn(Optional.empty());

        LoginRequest request = new LoginRequest();
        request.setEmail(" PERSONAL@EXAMPLE.COM ");
        request.setPassword("password");

        AuthResponse response = authService.login(request);

        assertEquals("token", response.getAccessToken());
        assertNull(response.getBusinessAccount());
    }

    private User mockUser(Long id, SubscriptionPlan plan) {
        User user = org.mockito.Mockito.mock(User.class);
        when(user.getId()).thenReturn(id);
        when(user.getFullName()).thenReturn("Test User");
        when(user.getEmail()).thenReturn(
                id == 7L ? "member@example.com" : "personal@example.com"
        );
        when(user.getSubscriptionPlan()).thenReturn(plan);
        return user;
    }
}
