package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.FreeAssistantQuotaExceededException;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.*;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class FreeAssistantEntitlementTest {
    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-10-16T11:00:00Z"), ZoneId.of("Europe/Istanbul"));
    private static final LocalDate MONTH_START = LocalDate.of(2026, 10, 1);
    private static final LocalDate NEXT_MONTH = LocalDate.of(2026, 11, 1);
    private static final LocalDateTime NOW = LocalDateTime.now(CLOCK);

    private AiAssistantAccessRepository accesses;
    private AiAssistantDailyUsageRepository usages;
    private AiAssistantQuotaReservationRepository reservations;
    private BusinessContextService context;
    private SubscriptionService subscriptions;
    private JdbcTemplate jdbc;
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
        jdbc = mock(JdbcTemplate.class);
        user = new User("User", "free@example.com", "password");
        ReflectionTestUtils.setField(user, "id", 7L);
        daily = new AiAssistantDailyUsage(user, LocalDate.now(CLOCK), NOW);
        var access = new AiAssistantAccess(user, NOW);
        when(context.requireUser("free@example.com")).thenReturn(user);
        when(accesses.findByUserId(7L)).thenReturn(Optional.of(access));
        when(subscriptions.getEffectivePlan(user)).thenReturn(SubscriptionPlan.FREE);
        entitlement = new AiAssistantEntitlementService(
                accesses, usages, reservations, context,
                subscriptions, jdbc, CLOCK, Duration.ofMinutes(5));
    }

    private void monthlyUsed(long count) {
        when(reservations.countFreeMonthlyCompleted(7L, MONTH_START, NEXT_MONTH))
                .thenReturn(count);
    }

    @Test
    void freePlanHasThreeQuestionsPerCalendarMonthWithoutPlusTrial() {
        monthlyUsed(0);
        var status = entitlement.status("free@example.com");
        assertEquals(AiAssistantAccessStatus.ACTIVE, status.status());
        assertEquals("MONTHLY", status.quotaPeriod());
        assertEquals(3, status.dailyLimit());
        assertEquals(3, status.remainingToday());
        assertTrue(status.canAsk());
        assertNull(status.trialExpiresAt());
        assertDoesNotThrow(() -> entitlement.assertCanAsk("free@example.com"));

        monthlyUsed(2);
        assertEquals(1, entitlement.status("free@example.com").remainingToday());
        monthlyUsed(3);
        assertEquals(0, entitlement.status("free@example.com").remainingToday());
        assertFalse(entitlement.status("free@example.com").canAsk());
        assertThrows(FreeAssistantQuotaExceededException.class,
                () -> entitlement.assertCanAsk("free@example.com"));
    }

    @Test
    void activeReservationCountsTowardMonthlyLimitAndBlocksFourthQuestion() {
        monthlyUsed(2);
        when(reservations.countFreeMonthlyReserved(7L, MONTH_START, NEXT_MONTH, NOW))
                .thenReturn(1L);
        assertEquals(0, entitlement.status("free@example.com").remainingToday());
        assertThrows(FreeAssistantQuotaExceededException.class,
                () -> entitlement.reserveQuestion("free@example.com"));
    }

    @Test
    void reservationUsesUserLockAndFreeMonthlyLabelToPreventDoubleSpending() {
        monthlyUsed(2);
        var token = entitlement.reserveQuestion("free@example.com");
        assertNotNull(token);
        var capture = ArgumentCaptor.forClass(AiAssistantQuotaReservation.class);
        verify(reservations).save(capture.capture());
        assertTrue(capture.getValue().isFreeMonthly());
        verify(jdbc).queryForObject(
                eq("SELECT id FROM users WHERE id = ? FOR UPDATE"),
                eq(Long.class), eq(7L));
    }

    @Test
    void freeCompletionDoesNotConsumePaidDailyQuota() {
        var token = UUID.randomUUID();
        var reservation = new AiAssistantQuotaReservation(
                token, user, MONTH_START.plusDays(15), NOW, NOW.plusMinutes(5));
        reservation.markFreeMonthly();
        when(reservations.findOwnedForUpdate(token, 7L))
                .thenReturn(Optional.of(reservation));

        entitlement.completeReservedQuestion("free@example.com", token);

        assertFalse(reservation.isActive(NOW.plusSeconds(1)));
        verifyNoInteractions(usages);
    }

    @Test
    void subscribedPlusAndProKeepExistingDailyLimitsAndCounters() {
        when(subscriptions.getEffectivePlan(user)).thenReturn(SubscriptionPlan.PLUS);
        when(usages.findByUserIdAndUsageDate(7L, LocalDate.now(CLOCK)))
                .thenReturn(Optional.of(daily));
        assertEquals("DAILY", entitlement.status("free@example.com").quotaPeriod());
        assertEquals(3, entitlement.status("free@example.com").dailyLimit());

        daily.recordSuccessful(NOW);
        assertEquals(2, entitlement.status("free@example.com").remainingToday());
        when(subscriptions.getEffectivePlan(user)).thenReturn(SubscriptionPlan.PRO);
        assertEquals(5, entitlement.status("free@example.com").dailyLimit());
        verify(reservations, never()).countFreeMonthlyCompleted(anyLong(), any(), any());
    }

    @Test
    void historicDailyPaidUsageDoesNotConsumeFreeMonthlyAllowance() {
        monthlyUsed(0);
        daily.recordSuccessful(NOW);
        daily.recordSuccessful(NOW);
        daily.recordSuccessful(NOW);
        when(usages.findByUserIdAndUsageDate(7L, LocalDate.now(CLOCK)))
                .thenReturn(Optional.of(daily));
        assertEquals(3, entitlement.status("free@example.com").remainingToday());
    }

    @Test
    void nextMonthResetsMonthlyAllowanceIndependentlyOfPreviousMonth() {
        Clock november = Clock.fixed(
                Instant.parse("2026-11-01T09:00:00Z"),
                ZoneId.of("Europe/Istanbul"));
        var nextMonthService = new AiAssistantEntitlementService(
                accesses, usages, reservations, context, subscriptions,
                jdbc, november, Duration.ofMinutes(5));
        var status = nextMonthService.status("free@example.com");
        assertEquals(3, status.remainingToday());
        verify(reservations).countFreeMonthlyCompleted(
                7L, LocalDate.of(2026, 11, 1), LocalDate.of(2026, 12, 1));
    }

    @Test
    void securityLockStillOverridesFreeAssistantAccess() {
        var access = new AiAssistantAccess(user, NOW);
        access.lockUntil(NOW.plusHours(24), NOW);
        when(accesses.findByUserId(7L)).thenReturn(Optional.of(access));

        var status = entitlement.status("free@example.com");
        assertEquals(AiAssistantAccessStatus.LOCKED, status.status());
        assertFalse(status.canAsk());
        assertThrows(IllegalStateException.class,
                () -> entitlement.assertCanAsk("free@example.com"));
    }
}
