package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.AppNotificationRepository;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.NotificationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {
    @Mock private AppNotificationRepository notifications;
    @Mock private BusinessContextService businessContext;

    private NotificationService service;
    private User user;

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(Instant.parse("2026-09-16T09:00:00Z"), ZoneOffset.UTC);
        service = new NotificationService(notifications, businessContext, clock);
        user = new User("Test User", "user@example.com", "password");
        org.springframework.test.util.ReflectionTestUtils.setField(user, "id", 42L);
    }

    @Test
    void markAllReadUpdatesEveryUnreadNotificationForCurrentUser() {
        when(businessContext.requireUser("user@example.com")).thenReturn(user);

        service.markAllRead("user@example.com");

        verify(notifications).markAllRead(
                42L, LocalDateTime.of(2026, 9, 16, 9, 0));
    }
}
