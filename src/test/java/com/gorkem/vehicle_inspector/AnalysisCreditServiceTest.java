package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import java.time.*;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AnalysisCreditServiceTest {
    @Mock AnalysisCreditTransactionRepository credits;
    @Mock AnalysisUsageRepository usages;
    @Mock UserRepository users;
    @Mock BusinessAccountRepository businesses;
    @Mock BusinessContextService businessContext;
    @Mock SubscriptionService subscriptions;

    AnalysisCreditService service;
    User user;
    DamageInspection inspection;

    @BeforeEach
    void setUp() {
        service = new AnalysisCreditService(
                credits, usages, users, businesses, businessContext,
                subscriptions, Clock.fixed(
                        Instant.parse("2026-09-29T12:00:00Z"), ZoneOffset.UTC));
        user = new User("Test User", "user@example.com", "test-value");
        ReflectionTestUtils.setField(user, "id", 7L);
        Vehicle vehicle = new Vehicle("35TEST01", "Test", "Car", 2024, 1000, user);
        inspection = new DamageInspection(vehicle, user, InspectionStatus.COMPLETED);
        ReflectionTestUtils.setField(inspection, "id", 11L);
        lenient()
                .when(users.findByIdForUpdate(7L))
                .thenReturn(Optional.of(user));
    }

    @Test
    void grantsPurchaseOnlyOnce() {
        when(credits.existsByExternalTransactionId("tx-1"))
                .thenReturn(false, false);

        service.grantPurchase(user, "analysis_3", "tx-1");

        ArgumentCaptor<AnalysisCreditTransaction> saved =
                ArgumentCaptor.forClass(AnalysisCreditTransaction.class);
        verify(credits).save(saved.capture());
        assertEquals(3, saved.getValue().getAmount());
        assertEquals(AnalysisCreditTransactionType.PURCHASE,
                saved.getValue().getType());

        reset(credits);
        when(credits.existsByExternalTransactionId("tx-1")).thenReturn(true);
        service.grantPurchase(user, "analysis_3", "tx-1");
        verify(credits, never()).save(any());
    }

    @Test
    void usesMonthlyFreeReportBeforeCredit() {
        when(usages.countByUser_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                eq(7L), any(LocalDateTime.class), any(LocalDateTime.class)))
                .thenReturn(0L);

        service.grantReportAccess(inspection, user);

        assertEquals(ReportAccessSource.FREE_MONTHLY,
                inspection.getReportAccessSource());
        verify(subscriptions).recordPersonalAnalysisUsage(
                eq(user), any(LocalDateTime.class));
        verify(credits, never()).save(any());
    }

    @Test
    void consumesOneCreditAfterFreeReport() {
        when(usages.countByUser_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                eq(7L), any(LocalDateTime.class), any(LocalDateTime.class)))
                .thenReturn(1L);
        when(credits.balanceByUserId(7L)).thenReturn(2L);

        service.grantReportAccess(inspection, user);

        assertEquals(ReportAccessSource.PURCHASED_CREDIT,
                inspection.getReportAccessSource());
        ArgumentCaptor<AnalysisCreditTransaction> saved =
                ArgumentCaptor.forClass(AnalysisCreditTransaction.class);
        verify(credits).save(saved.capture());
        assertEquals(-1, saved.getValue().getAmount());
        assertEquals(AnalysisCreditTransactionType.CONSUME,
                saved.getValue().getType());
    }

    @Test
    void retryDoesNotConsumeAgain() {
        inspection.grantReportAccess(ReportAccessSource.PURCHASED_CREDIT);
        service.grantReportAccess(inspection, user);
        verifyNoInteractions(usages, credits, subscriptions);
    }
}
