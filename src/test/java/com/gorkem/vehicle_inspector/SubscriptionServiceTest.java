package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import com.gorkem.vehicle_inspector.repository.RewardedAnalysisSessionRepository;
import com.gorkem.vehicle_inspector.service.SubscriptionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.time.ZoneId;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SubscriptionServiceTest {
    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-09-16T10:00:00Z"), ZoneId.of("Europe/Istanbul"));
    private static final LocalDateTime NOW = LocalDateTime.now(CLOCK);
    private static final LocalDateTime MONTH_START = LocalDateTime.of(2026, 9, 1, 0, 0);
    private static final LocalDateTime NEXT_MONTH = LocalDateTime.of(2026, 10, 1, 0, 0);

    @Mock private DamageInspectionRepository inspections;
    @Mock private VehicleRepository vehicles;
    @Mock private RewardedAnalysisSessionRepository rewardedSessions;
    @Mock private User user;
    private SubscriptionService service;

    @BeforeEach
    void setUp() {
        service = new SubscriptionService(inspections, vehicles, rewardedSessions, CLOCK);
        lenient().when(user.getId()).thenReturn(1L);
    }

    @Test
    void freeUserFirstMonthlyAnalysisIsAllowed() {
        plan(SubscriptionPlan.FREE);
        when(inspections.countPersonalAnalysesBetween(1L, MONTH_START, NEXT_MONTH)).thenReturn(0L);
        assertDoesNotThrow(() -> service.validatePersonalMonthlyAnalysisLimit(user, NOW));
    }

    @Test
    void freeUserSecondMonthlyAnalysisIsBlocked() {
        plan(SubscriptionPlan.FREE);
        when(inspections.countPersonalAnalysesBetween(1L, MONTH_START, NEXT_MONTH)).thenReturn(1L);
        assertThrows(IllegalStateException.class,
                () -> service.validatePersonalMonthlyAnalysisLimit(user, NOW));
    }

    @Test
    void verifiedRewardAllowsExactlyOneAdditionalFreeAnalysis() {
        plan(SubscriptionPlan.FREE);
        when(rewardedSessions.existsByUserIdAndMonthStartAndClaimedAtIsNotNull(
                1L, LocalDate.of(2026, 9, 1))).thenReturn(true);
        when(inspections.countPersonalAnalysesBetween(1L, MONTH_START, NEXT_MONTH))
                .thenReturn(1L, 2L);

        assertDoesNotThrow(() -> service.validatePersonalMonthlyAnalysisLimit(user, NOW));
        assertThrows(IllegalStateException.class,
                () -> service.validatePersonalMonthlyAnalysisLimit(user, NOW));
    }

    @Test
    void previousMonthDoesNotAffectFreeUser() {
        plan(SubscriptionPlan.FREE);
        LocalDateTime october = LocalDateTime.of(2026, 10, 3, 9, 0);
        when(inspections.countPersonalAnalysesBetween(1L,
                LocalDateTime.of(2026, 10, 1, 0, 0),
                LocalDateTime.of(2026, 11, 1, 0, 0))).thenReturn(0L);
        assertDoesNotThrow(() -> service.validatePersonalMonthlyAnalysisLimit(user, october));
    }

    @Test
    void plusAllowsFiveAndBlocksSixthAnalysis() {
        plan(SubscriptionPlan.PLUS);
        when(inspections.countPersonalAnalysesBetween(1L, MONTH_START, NEXT_MONTH)).thenReturn(4L, 5L);
        assertDoesNotThrow(() -> service.validatePersonalMonthlyAnalysisLimit(user, NOW));
        assertThrows(IllegalStateException.class,
                () -> service.validatePersonalMonthlyAnalysisLimit(user, NOW));
    }

    @Test
    void proAllowsTwentyAndBlocksTwentyFirstAnalysis() {
        plan(SubscriptionPlan.PRO);
        when(inspections.countPersonalAnalysesBetween(1L, MONTH_START, NEXT_MONTH)).thenReturn(19L, 20L);
        assertDoesNotThrow(() -> service.validatePersonalMonthlyAnalysisLimit(user, NOW));
        assertThrows(IllegalStateException.class,
                () -> service.validatePersonalMonthlyAnalysisLimit(user, NOW));
    }

    @Test
    void businessPlanWithoutMembershipHasNoPersonalQuotaFallback() {
        plan(SubscriptionPlan.BUSINESS);
        assertThrows(IllegalStateException.class,
                () -> service.validatePersonalMonthlyAnalysisLimit(user, NOW));
        verifyNoInteractions(inspections);
    }

    @Test
    void businessSharedMonthlyLimitIsOneHundred() {
        BusinessAccount business = mock(BusinessAccount.class);
        when(business.getId()).thenReturn(10L);
        when(inspections.countBusinessAnalysesBetween(10L, MONTH_START, NEXT_MONTH)).thenReturn(99L, 100L);
        assertDoesNotThrow(() -> service.validateBusinessMonthlyAnalysisLimit(business, NOW));
        assertThrows(IllegalStateException.class,
                () -> service.validateBusinessMonthlyAnalysisLimit(business, NOW));
    }

    @Test
    void freeVehicleLimitIsOne() {
        plan(SubscriptionPlan.FREE);
        when(vehicles.countByUserIdAndArchivedFalse(1L)).thenReturn(1L);
        assertThrows(IllegalStateException.class, () -> service.validateVehicleLimit(user));
    }

    @Test
    void plusVehicleLimitIsThree() {
        plan(SubscriptionPlan.PLUS);
        when(vehicles.countByUserIdAndArchivedFalse(1L)).thenReturn(2L, 3L);
        assertDoesNotThrow(() -> service.validateVehicleLimit(user));
        assertThrows(IllegalStateException.class, () -> service.validateVehicleLimit(user));
    }

    @Test
    void proVehicleLimitIsTen() {
        plan(SubscriptionPlan.PRO);
        when(vehicles.countByUserIdAndArchivedFalse(1L)).thenReturn(9L, 10L);
        assertDoesNotThrow(() -> service.validateVehicleLimit(user));
        assertThrows(IllegalStateException.class, () -> service.validateVehicleLimit(user));
    }

    @Test
    void expiredPaidPlanUsesFreeLimits() {
        when(user.getSubscriptionPlan()).thenReturn(SubscriptionPlan.PLUS);
        when(user.getSubscriptionExpiresAt()).thenReturn(NOW.minusSeconds(1));
        when(vehicles.countByUserIdAndArchivedFalse(1L)).thenReturn(1L);
        assertThrows(IllegalStateException.class, () -> service.validateVehicleLimit(user));
    }

    @Test
    void businessVehicleLimitIsSharedAtFifty() {
        BusinessAccount business = mock(BusinessAccount.class);
        when(business.getId()).thenReturn(10L);
        when(vehicles.countByBusinessAccountIdAndArchivedFalse(10L)).thenReturn(49L, 50L);
        assertDoesNotThrow(() -> service.validateBusinessVehicleLimit(business));
        assertThrows(IllegalStateException.class,
                () -> service.validateBusinessVehicleLimit(business));
    }

    private void plan(SubscriptionPlan plan) {
        when(user.getSubscriptionPlan()).thenReturn(plan);
        if (plan != SubscriptionPlan.FREE) {
            when(user.getSubscriptionExpiresAt()).thenReturn(NOW.plusMonths(1));
        }
    }
}
