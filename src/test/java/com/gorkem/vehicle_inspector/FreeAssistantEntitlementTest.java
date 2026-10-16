package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.*;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class FreeAssistantEntitlementTest {
    private final Clock clock = Clock.fixed(
            Instant.parse("2026-10-16T11:00:00Z"),
            ZoneId.of("Europe/Istanbul"));

    private AiAssistantAccessRepository accesses;
    private AiAssistantDailyUsageRepository usages;
    private AiAssistantQuotaReservationRepository reservations;
    private BusinessContextService context;
    private SubscriptionService subscriptions;
    private AiAssistantEntitlementService entitlement;
    private User user;
    private AiAssistantDailyUsage daily;

    @BeforeEach
    void setUp() {
        accesses = mock(AiAssistantAccessRepository.class);
        usages = mock(AiAssistantDailyUsageRepository.class);
        reservations = mock(AiAssistantQuotaReservationRepository.class);
        context = mock(BusinessContextService.class);
        subscriptions = mock(SubscriptionService.class);
        user = new User("User", "free@example.com", "password");
        ReflectionTestUtils.setField(user, "id", 7L);
        daily = new AiAssistantDailyUsage(
                user, LocalDate.now(clock), LocalDateTime.now(clock));
        var access = new AiAssistantAccess(user, LocalDateTime.now(clock));
        when(context.requireUser("free@example.com")).thenReturn(user);
        when(accesses.findByUserId(7L)).thenReturn(Optional.of(access));
        when(usages.findByUserIdAndUsageDate(7L, LocalDate.now(clock)))
                .thenReturn(Optional.of(daily));
        when(usages.findForUpdate(7L, LocalDate.now(clock)))
                .thenReturn(Optional.of(daily));
        when(subscriptions.getEffectivePlan(user)).thenReturn(SubscriptionPlan.FREE);
        entitlement = new AiAssistantEntitlementService(
                accesses, usages, reservations, context,
                subscriptions, null, clock, Duration.ofMinutes(5));
    }

    @Test
    void freePlanCanAskThreeQuestionsWithoutStartingAnyTrial() {
        var status = entitlement.status("free@example.com");
        assertEquals(AiAssistantAccessStatus.ACTIVE, status.status());
        assertTrue(status.canAsk());
        assertEquals(3, status.dailyLimit());
        assertEquals(3, status.remainingToday());
        assertNull(status.trialExpiresAt());
        assertDoesNotThrow(() -> entitlement.assertCanAsk("free@example.com"));

        daily.recordSuccessful(LocalDateTime.now(clock));
        daily.recordSuccessful(LocalDateTime.now(clock));
        daily.recordSuccessful(LocalDateTime.now(clock));

        assertEquals(0, entitlement.status("free@example.com").remainingToday());
        assertFalse(entitlement.status("free@example.com").canAsk());
        assertThrows(IllegalStateException.class,
                () -> entitlement.assertCanAsk("free@example.com"));
    }

    @Test
    void activePaidPlansKeepCurrentThreeOrFiveDailyLimits() {
        when(subscriptions.getEffectivePlan(user)).thenReturn(SubscriptionPlan.PLUS);
        assertEquals(3, entitlement.status("free@example.com").dailyLimit());
        when(subscriptions.getEffectivePlan(user)).thenReturn(SubscriptionPlan.PRO);
        assertEquals(5, entitlement.status("free@example.com").dailyLimit());
    }

    @Test
    void existingSecurityLockStillOverridesFreeAccess() {
        var access = new AiAssistantAccess(user, LocalDateTime.now(clock));
        access.lockUntil(LocalDateTime.now(clock).plusHours(24),
                LocalDateTime.now(clock));
        when(accesses.findByUserId(7L)).thenReturn(Optional.of(access));

        var status = entitlement.status("free@example.com");
        assertEquals(AiAssistantAccessStatus.LOCKED, status.status());
        assertFalse(status.canAsk());
        assertThrows(IllegalStateException.class,
                () -> entitlement.assertCanAsk("free@example.com"));
    }
}
