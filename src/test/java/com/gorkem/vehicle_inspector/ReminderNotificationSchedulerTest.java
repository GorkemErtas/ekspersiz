package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.AppNotificationRepository;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.VehicleReminderRepository;
import com.gorkem.vehicle_inspector.service.FcmPushService;
import com.gorkem.vehicle_inspector.service.ReminderNotificationScheduler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.*;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ReminderNotificationSchedulerTest {
    @Mock private VehicleReminderRepository reminders;
    @Mock private BusinessMemberRepository members;
    @Mock private AppNotificationRepository notifications;
    @Mock private FcmPushService push;

    private ReminderNotificationScheduler scheduler;
    private User user;
    private Vehicle vehicle;

    @BeforeEach
    void setUp() {
        scheduler = new ReminderNotificationScheduler(reminders, members,
                notifications, push, Clock.fixed(
                Instant.parse("2026-09-16T09:00:00Z"), ZoneOffset.UTC));
        user = mock(User.class);
        lenient().when(user.getId()).thenReturn(1L);
        vehicle = new Vehicle("35ABC123", "Honda", "City", 2022, 100_000, user);
        ReflectionTestUtils.setField(vehicle, "id", 5L);
        lenient().when(notifications.save(any())).thenAnswer(call -> call.getArgument(0));
        lenient().when(notifications.saveAndFlush(any())).thenAnswer(call -> call.getArgument(0));
    }

    @Test
    void importantDateShouldCreateOneInAppAndPushNotificationIdempotently() {
        VehicleReminder reminder = reminder(ReminderType.VEHICLE_INSPECTION,
                LocalDate.of(2026, 9, 23), null);
        when(reminders.findAllByCompletedAtIsNull()).thenReturn(List.of(reminder));
        when(notifications.existsByUserIdAndEventKey(1L, "reminder:8:date:7"))
                .thenReturn(false, true);

        scheduler.evaluateDueReminders();
        scheduler.evaluateDueReminders();

        ArgumentCaptor<AppNotification> captor = ArgumentCaptor.forClass(AppNotification.class);
        verify(notifications).save(captor.capture());
        assertEquals(NotificationSeverity.WARNING, captor.getValue().getSeverity());
        verify(push).send(captor.getValue());
    }

    @Test
    void mileageThresholdShouldCreateInAppAndPushNotification() {
        VehicleReminder reminder = reminder(ReminderType.PERIODIC_MAINTENANCE,
                null, 101_500);
        when(reminders.findAllByCompletedAtIsNull()).thenReturn(List.of(reminder));
        when(notifications.existsByUserIdAndEventKey(1L, "reminder:8:mileage:2000"))
                .thenReturn(false);

        scheduler.evaluateDueReminders();

        verify(notifications).save(any(AppNotification.class));
        verify(push).send(any(AppNotification.class));
    }

    @Test
    void businessReminderShouldCreateOneNotificationPerCurrentMember() {
        BusinessAccount business = new BusinessAccount("ABC Ekspertiz");
        ReflectionTestUtils.setField(business, "id", 10L);
        vehicle = new Vehicle("35ABC123", "Honda", "City", 2022, 100_000, business);
        ReflectionTestUtils.setField(vehicle, "id", 5L);
        User second = mock(User.class);
        when(second.getId()).thenReturn(2L);
        when(members.findByBusinessAccountId(10L)).thenReturn(List.of(
                new BusinessMember(business, user, BusinessRole.OWNER),
                new BusinessMember(business, second, BusinessRole.MEMBER)));
        VehicleReminder reminder = reminder(ReminderType.TIRE_CHECK,
                LocalDate.of(2026, 10, 16), null);
        when(reminders.findAllByCompletedAtIsNull()).thenReturn(List.of(reminder));

        scheduler.evaluateDueReminders();

        verify(notifications, times(2)).save(any(AppNotification.class));
        verify(push, times(2)).send(any(AppNotification.class));
    }

    private VehicleReminder reminder(ReminderType type, LocalDate date, Integer mileage) {
        VehicleReminder reminder = new VehicleReminder(vehicle, user, type,
                null, date, mileage, null, LocalDateTime.of(2026, 9, 1, 10, 0));
        ReflectionTestUtils.setField(reminder, "id", 8L);
        return reminder;
    }
}
