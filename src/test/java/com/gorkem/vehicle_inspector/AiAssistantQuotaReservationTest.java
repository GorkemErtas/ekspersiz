package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import java.util.Optional;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import java.time.*;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

class AiAssistantQuotaReservationTest {
    private static final LocalDateTime START = LocalDateTime.of(2026, 10, 8, 23, 59);

    @Test
    void completionAfterMidnightKeepsOriginalUsageDate() {
        User user = new User("Test User", "test@example.com", "password");
        AiAssistantQuotaReservation reservation = new AiAssistantQuotaReservation(
                UUID.randomUUID(), user, START.toLocalDate(), START, START.plusMinutes(5));
        reservation.complete(START.plusMinutes(2));
        assertEquals(LocalDate.of(2026, 10, 8), reservation.getUsageDate());
        assertFalse(reservation.isActive(START.plusMinutes(2)));
    }

    @Test
    void personalCompletionAfterMidnightChargesReservationDay() {
        User user = new User("Test User", "test@example.com", "password");
        ReflectionTestUtils.setField(user, "id", 7L);
        UUID token = UUID.randomUUID();
        AiAssistantQuotaReservation reservation = new AiAssistantQuotaReservation(
                token, user, START.toLocalDate(), START, START.plusMinutes(5));
        AiAssistantAccessRepository accesses = mock(AiAssistantAccessRepository.class);
        AiAssistantDailyUsageRepository usages = mock(AiAssistantDailyUsageRepository.class);
        AiAssistantQuotaReservationRepository reservations = mock(AiAssistantQuotaReservationRepository.class);
        BusinessContextService context = mock(BusinessContextService.class);
        Clock afterMidnight = Clock.fixed(
                START.plusMinutes(2).atZone(ZoneId.of("Europe/Istanbul")).toInstant(),
                ZoneId.of("Europe/Istanbul"));
        AiAssistantDailyUsage previousDay = new AiAssistantDailyUsage(
                user, START.toLocalDate(), START);
        when(context.requireUser("test@example.com")).thenReturn(user);
        when(reservations.findOwnedForUpdate(token, 7L)).thenReturn(Optional.of(reservation));
        when(usages.findForUpdate(7L, START.toLocalDate())).thenReturn(Optional.of(previousDay));
        AiAssistantEntitlementService service = new AiAssistantEntitlementService(
                accesses, usages, reservations, context, null, null,
                afterMidnight, Duration.ofMinutes(5));

        service.completeReservedQuestion("test@example.com", token);

        verify(usages).ensureDailyRow(7L, START.toLocalDate());
        verify(usages).findForUpdate(7L, START.toLocalDate());
        assertEquals(1, previousDay.getSuccessfulQuestions());
        assertFalse(reservation.isActive(START.plusMinutes(2)));
    }

    @Test
    void reservationReferencesSharedBusinessAccount() {
        User user = new User("Test User", "test@example.com", "password");
        BusinessAccount business = new BusinessAccount("Example Ltd");
        ReflectionTestUtils.setField(business, "id", 42L);
        AiAssistantQuotaReservation reservation = new AiAssistantQuotaReservation(
                UUID.randomUUID(), user, START.toLocalDate(), START, START.plusMinutes(5));
        reservation.assignBusiness(business);
        assertEquals(42L, reservation.getBusinessAccountId());
    }

    @Test
    void expiredReservationCannotComplete() {
        User user = new User("Test User", "test@example.com", "password");
        AiAssistantQuotaReservation reservation = new AiAssistantQuotaReservation(
                UUID.randomUUID(), user, START.toLocalDate(), START, START.plusMinutes(5));
        assertThrows(IllegalStateException.class,
                () -> reservation.complete(START.plusMinutes(6)));
    }
}
