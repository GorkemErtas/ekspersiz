package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.util.ReflectionTestUtils;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AiAssistantBusinessQuotaTest {
    @Mock AiAssistantAccessRepository accesses;
    @Mock AiAssistantDailyUsageRepository usages;
    @Mock AiAssistantQuotaReservationRepository reservations;
    @Mock BusinessContextService businessContext;
    @Mock SubscriptionService subscriptions;
    @Mock JdbcTemplate jdbc;

    private final Clock clock = Clock.fixed(Instant.parse("2026-10-08T09:00:00Z"),
            ZoneId.of("Europe/Istanbul"));

    @Test
    void sharedBusinessQuotaRejectsEleventhReservation() {
        User owner = new User("Owner", "owner@example.com", "password");
        ReflectionTestUtils.setField(owner, "id", 1L);
        User employee = new User("Employee", "employee@example.com", "password");
        ReflectionTestUtils.setField(employee, "id", 2L);
        BusinessAccount company = new BusinessAccount("Test Company");
        ReflectionTestUtils.setField(company, "id", 11L);
        AiAssistantAccess ownerAccess = new AiAssistantAccess(owner, LocalDateTime.now(clock));
        AiAssistantAccess employeeAccess = new AiAssistantAccess(employee, LocalDateTime.now(clock));

        when(businessContext.requireUser("owner@example.com")).thenReturn(owner);
        when(businessContext.requireUser("employee@example.com")).thenReturn(employee);
        when(businessContext.isBusinessMember(any(User.class))).thenReturn(true);
        when(businessContext.requireBusinessAccount(any(User.class))).thenReturn(company);
        when(accesses.findByUserId(1L)).thenReturn(Optional.of(ownerAccess));
        when(accesses.findByUserId(2L)).thenReturn(Optional.of(employeeAccess));
        when(jdbc.queryForObject(contains("SELECT id FROM business_accounts"), eq(Long.class), eq(11L)))
                .thenReturn(11L);
        when(jdbc.queryForObject(contains("COALESCE(SUM(successful_questions)"), eq(Integer.class),
                eq(11L), any(java.sql.Date.class))).thenReturn(9);
        when(reservations.countBusinessActive(eq(11L), any(LocalDate.class),
                any(LocalDateTime.class))).thenReturn(0L, 1L);

        AiAssistantEntitlementService service = new AiAssistantEntitlementService(
                accesses, usages, reservations, businessContext, subscriptions, jdbc,
                clock, Duration.ofMinutes(5));

        UUID token = service.reserveQuestion("owner@example.com");
        InOrder firstRequest = inOrder(reservations, jdbc);
        firstRequest.verify(reservations).releaseExpired(any(LocalDateTime.class));
        firstRequest.verify(jdbc).queryForObject(
                contains("SELECT id FROM business_accounts"), eq(Long.class), eq(11L));
        assertNotNull(token);
        verify(reservations).save(argThat(r -> Long.valueOf(11L).equals(r.getBusinessAccountId())));
        assertThrows(IllegalStateException.class,
                () -> service.reserveQuestion("employee@example.com"));
        verify(reservations, times(1)).save(any(AiAssistantQuotaReservation.class));
    }
}
