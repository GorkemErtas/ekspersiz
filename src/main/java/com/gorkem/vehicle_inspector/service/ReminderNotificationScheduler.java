package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.AppNotificationRepository;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.VehicleReminderRepository;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class ReminderNotificationScheduler {
    private static final List<Integer> DATE_THRESHOLDS = List.of(30, 7, 1, 0);
    private final VehicleReminderRepository reminders;
    private final BusinessMemberRepository members;
    private final AppNotificationRepository notifications;
    private final FcmPushService push;
    private final Clock clock;

    public ReminderNotificationScheduler(VehicleReminderRepository reminders,
                                         BusinessMemberRepository members,
                                         AppNotificationRepository notifications,
                                         FcmPushService push, Clock clock) {
        this.reminders = reminders;
        this.members = members;
        this.notifications = notifications;
        this.push = push;
        this.clock = clock;
    }

    @Scheduled(cron = "${application.notifications.schedule-cron:0 0 9 * * *}",
            zone = "${application.notifications.time-zone:Europe/Istanbul}")
    @Transactional
    public void evaluateDueReminders() {
        for (VehicleReminder reminder : reminders.findAllByCompletedAtIsNull()) {
            evaluate(reminder);
        }
    }

    void evaluate(VehicleReminder reminder) {
        LocalDate today = LocalDate.now(clock);
        if (reminder.getDueDate() != null) {
            long days = ChronoUnit.DAYS.between(today, reminder.getDueDate());
            if (days < 0) {
                createForRecipients(reminder, "date:overdue",
                        NotificationSeverity.CRITICAL, title(reminder),
                        reminder.getVehicle().getPlate() + " için tarih geçti.",
                        isImportantDate(reminder.getReminderType()));
            } else if (DATE_THRESHOLDS.contains((int) days)) {
                boolean importantPush = isImportantDate(reminder.getReminderType())
                        && (days == 7 || days == 1 || days == 0);
                createForRecipients(reminder, "date:" + days,
                        severity(days), title(reminder), dateBody(reminder, days), importantPush);
            }
        }

        if (reminder.getDueMileage() != null) {
            int remaining = reminder.getDueMileage() - reminder.getVehicle().getMileage();
            Integer threshold = remaining <= 0 ? 0 : remaining <= 500 ? 500
                    : remaining <= 2_000 ? 2_000 : null;
            if (threshold != null) {
                createForRecipients(reminder, "mileage:" + threshold,
                        threshold == 0 ? NotificationSeverity.CRITICAL : NotificationSeverity.WARNING,
                        title(reminder), mileageBody(reminder, remaining), false);
            }
        }
    }

    private void createForRecipients(VehicleReminder reminder, String thresholdKey,
                                     NotificationSeverity severity, String title,
                                     String body, boolean sendPush) {
        for (User recipient : recipients(reminder.getVehicle())) {
            String eventKey = "reminder:" + reminder.getId() + ":" + thresholdKey;
            if (notifications.existsByUserIdAndEventKey(recipient.getId(), eventKey)) continue;
            LocalDateTime now = LocalDateTime.now(clock);
            AppNotification notification = notifications.save(new AppNotification(
                    recipient, reminder.getVehicle(), reminder, eventKey,
                    NotificationType.VEHICLE_REMINDER, severity, title, body,
                    "vehicle:" + reminder.getVehicle().getId(), now));
            if (sendPush) {
                notification.markPushAttempted(now);
                notifications.saveAndFlush(notification);
                push.send(notification);
            }
        }
    }

    private List<User> recipients(Vehicle vehicle) {
        if (vehicle.getBusinessAccount() == null) {
            return vehicle.getUser() == null ? List.of() : List.of(vehicle.getUser());
        }
        return members.findByBusinessAccountId(vehicle.getBusinessAccount().getId())
                .stream().map(BusinessMember::getUser).toList();
    }

    private boolean isImportantDate(ReminderType type) {
        return type == ReminderType.VEHICLE_INSPECTION
                || type == ReminderType.TRAFFIC_INSURANCE
                || type == ReminderType.COMPREHENSIVE_INSURANCE;
    }

    private NotificationSeverity severity(long days) {
        return days == 0 ? NotificationSeverity.CRITICAL
                : days <= 7 ? NotificationSeverity.WARNING : NotificationSeverity.INFO;
    }

    private String title(VehicleReminder reminder) {
        if (reminder.getTitle() != null) return reminder.getTitle();
        return switch (reminder.getReminderType()) {
            case PERIODIC_MAINTENANCE -> "Periyodik bakım";
            case VEHICLE_INSPECTION -> "Araç muayenesi / TÜVTÜRK";
            case TRAFFIC_INSURANCE -> "Trafik sigortası";
            case COMPREHENSIVE_INSURANCE -> "Kasko";
            case TIRE_CHECK -> "Lastik kontrolü";
            case CUSTOM -> "Araç hatırlatması";
        };
    }

    private String dateBody(VehicleReminder reminder, long days) {
        String plate = reminder.getVehicle().getPlate();
        if (days == 0) return plate + " için son gün bugün.";
        return plate + " için " + days + " gün kaldı.";
    }

    private String mileageBody(VehicleReminder reminder, int remaining) {
        String plate = reminder.getVehicle().getPlate();
        if (remaining <= 0) return plate + " hedef kilometreye ulaştı.";
        return plate + " için yaklaşık " + remaining + " km kaldı.";
    }
}
