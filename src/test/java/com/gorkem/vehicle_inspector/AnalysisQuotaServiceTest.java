package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.response.AnalysisQuotaResponse;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.service.AnalysisQuotaService;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.SubscriptionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AnalysisQuotaServiceTest {

    @Mock private BusinessContextService businessContext;
    @Mock private SubscriptionService subscriptions;
    @Mock private DamageInspectionRepository inspections;

    private AnalysisQuotaService service;
    private User user;

    private final Clock clock = Clock.fixed(
            Instant.parse("2026-09-16T09:00:00Z"),
            ZoneOffset.UTC
    );

    @BeforeEach
    void setUp() {
        service = new AnalysisQuotaService(
                businessContext,
                subscriptions,
                inspections,
                clock
        );
        user = new User("Test User", "user@example.com", "password");
        ReflectionTestUtils.setField(user, "id", 42L);
        when(businessContext.requireUser("user@example.com"))
                .thenReturn(user);
    }

    @Test
    void personalQuotaContainsOnlySubscriptionLimit() {
        when(businessContext.findMembership(user))
                .thenReturn(Optional.empty());
        when(subscriptions.getEffectivePlan(user))
                .thenReturn(SubscriptionPlan.FREE);
        when(subscriptions.monthlyAnalysisLimit(SubscriptionPlan.FREE))
                .thenReturn(1);
        when(inspections.countPersonalAnalysesBetween(
                42L,
                LocalDateTime.of(2026, 9, 1, 0, 0),
                LocalDateTime.of(2026, 10, 1, 0, 0)
        )).thenReturn(1L);

        AnalysisQuotaResponse result =
                service.getQuota("user@example.com");

        assertEquals(SubscriptionPlan.FREE, result.plan());
        assertEquals(1, result.used());
        assertEquals(1, result.limit());
        assertEquals(0, result.remaining());
    }

    @Test
    void businessQuotaIsSharedAcrossTheAccount() {
        BusinessAccount business = new BusinessAccount("Test Company");
        ReflectionTestUtils.setField(business, "id", 10L);
        when(businessContext.findMembership(user)).thenReturn(
                Optional.of(
                        new BusinessMember(
                                business,
                                user,
                                BusinessRole.MEMBER
                        )
                )
        );
        when(businessContext.requireBusinessAccount(user))
                .thenReturn(business);
        when(subscriptions.businessMonthlyAnalysisLimit())
                .thenReturn(100);
        when(inspections.countBusinessAnalysesBetween(
                10L,
                LocalDateTime.of(2026, 9, 1, 0, 0),
                LocalDateTime.of(2026, 10, 1, 0, 0)
        )).thenReturn(99L);

        AnalysisQuotaResponse result =
                service.getQuota("user@example.com");

        assertEquals(SubscriptionPlan.BUSINESS, result.plan());
        assertEquals(99, result.used());
        assertEquals(100, result.limit());
        assertEquals(1, result.remaining());
    }
}
