package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.response.AnalysisQuotaResponse;
import com.gorkem.vehicle_inspector.dto.response.RewardedAdSessionResponse;
import com.gorkem.vehicle_inspector.entity.RewardedAnalysisSession;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.repository.RewardedAnalysisSessionRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.AdMobSsvVerifier;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.RewardedAnalysisService;
import com.gorkem.vehicle_inspector.service.SubscriptionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RewardedAnalysisServiceTest {
    @Mock private BusinessContextService businessContext;
    @Mock private SubscriptionService subscriptions;
    @Mock private DamageInspectionRepository inspections;
    @Mock private RewardedAnalysisSessionRepository sessions;
    @Mock private UserRepository users;
    @Mock private AdMobSsvVerifier verifier;

    private RewardedAnalysisService service;
    private User user;
    private final Clock clock = Clock.fixed(
            Instant.parse("2026-09-16T09:00:00Z"), ZoneOffset.UTC);

    @BeforeEach
    void setUp() {
        service = new RewardedAnalysisService(businessContext, subscriptions,
                inspections, sessions, users, verifier, clock);
        user = new User("Test User", "user@example.com", "password");
        ReflectionTestUtils.setField(user, "id", 42L);
    }

    @Test
    void quotaOffersOneRewardOnlyAfterFreeBaseQuotaIsUsed() {
        when(businessContext.requireUser("user@example.com")).thenReturn(user);
        when(businessContext.findMembership(user)).thenReturn(Optional.empty());
        when(subscriptions.getEffectivePlan(user)).thenReturn(SubscriptionPlan.FREE);
        when(subscriptions.monthlyAnalysisLimit(SubscriptionPlan.FREE)).thenReturn(1);
        when(inspections.countPersonalAnalysesBetween(42L,
                LocalDateTime.of(2026, 9, 1, 0, 0),
                LocalDateTime.of(2026, 10, 1, 0, 0))).thenReturn(1L);

        AnalysisQuotaResponse result = service.quota("user@example.com");

        assertTrue(result.rewardedEligible());
        assertFalse(result.rewardedClaimed());
        assertEquals(1, result.totalLimit());
        assertEquals(0, result.remaining());
    }

    @Test
    void createSessionUsesServerTokenAndAuthenticatedCustomerIdentity() {
        when(businessContext.requireUser("user@example.com")).thenReturn(user);
        when(businessContext.findMembership(user)).thenReturn(Optional.empty());
        when(subscriptions.getEffectivePlan(user)).thenReturn(SubscriptionPlan.FREE);
        when(users.findByIdForUpdate(42L)).thenReturn(Optional.of(user));
        when(subscriptions.monthlyAnalysisLimit(SubscriptionPlan.FREE)).thenReturn(1);
        when(inspections.countPersonalAnalysesBetween(anyLong(), any(), any())).thenReturn(1L);
        when(sessions.findByUserIdAndMonthStart(42L, LocalDate.of(2026, 9, 1)))
                .thenReturn(Optional.empty());
        when(sessions.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        RewardedAdSessionResponse result = service.createSession("user@example.com");

        assertEquals(user.getBillingCustomerId(), result.userId());
        assertNotNull(result.customData());
        assertEquals(LocalDateTime.of(2026, 9, 16, 9, 30), result.expiresAt());
        verify(users).save(user);
    }

    @Test
    void validSsvClaimsSessionOnlyAfterSignatureVerification() {
        RewardedAnalysisSession session = new RewardedAnalysisSession(
                user, LocalDate.of(2026, 9, 1), "server-token",
                LocalDateTime.of(2026, 9, 16, 9, 30),
                LocalDateTime.of(2026, 9, 16, 9, 0));
        when(sessions.existsByTransactionId("transaction-1")).thenReturn(false);
        when(sessions.findByTokenForUpdate("server-token")).thenReturn(Optional.of(session));

        service.acceptSsv("raw-signed-query", "server-token",
                user.getBillingCustomerId(), "transaction-1",
                Instant.now(clock).toEpochMilli());

        verify(verifier).verify("raw-signed-query");
        ArgumentCaptor<RewardedAnalysisSession> captor =
                ArgumentCaptor.forClass(RewardedAnalysisSession.class);
        verify(sessions).save(captor.capture());
        assertEquals("transaction-1", captor.getValue().getTransactionId());
        assertEquals(LocalDateTime.of(2026, 9, 16, 9, 0),
                captor.getValue().getClaimedAt());
    }
}
