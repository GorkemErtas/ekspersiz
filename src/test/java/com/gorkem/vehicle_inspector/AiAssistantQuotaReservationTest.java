package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
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
