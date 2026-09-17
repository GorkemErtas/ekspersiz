package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.ReminderRequest;
import com.gorkem.vehicle_inspector.dto.response.ReminderResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.AppNotificationRepository;
import com.gorkem.vehicle_inspector.repository.VehicleReminderRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class ReminderService {
    private static final int DUE_SOON_DAYS = 30;
    private static final int DUE_SOON_KILOMETERS = 2_000;
    private final VehicleReminderRepository reminders;
    private final AppNotificationRepository notifications;
    private final BusinessContextService businessContext;
    private final VehicleAccessService vehicleAccess;
    private final Clock clock;

    public ReminderService(VehicleReminderRepository reminders,
                           AppNotificationRepository notifications,
                           BusinessContextService businessContext,
                           VehicleAccessService vehicleAccess, Clock clock) {
        this.reminders = reminders; this.notifications = notifications;
        this.businessContext = businessContext;
        this.vehicleAccess = vehicleAccess; this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<ReminderResponse> list(Long vehicleId, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireVehicleIncludingArchived(vehicleId, user);
        return reminders.findAllByVehicleIdOrderByCompletedAtAscDueDateAscIdDesc(vehicle.getId())
                .stream().map(item -> toResponse(item, vehicle.getMileage())).toList();
    }

    @Transactional
    public ReminderResponse create(Long vehicleId, ReminderRequest request, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireActiveVehicle(vehicleId, user);
        validate(request);
        return toResponse(reminders.save(new VehicleReminder(vehicle, user,
                request.reminderType(), request.title(), request.dueDate(),
                request.dueMileage(), request.note(), LocalDateTime.now(clock))), vehicle.getMileage());
    }

    @Transactional
    public ReminderResponse update(Long vehicleId, Long reminderId,
                                   ReminderRequest request, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireActiveVehicle(vehicleId, user);
        VehicleReminder reminder = require(reminderId, vehicle.getId());
        validate(request);
        reminder.update(request.reminderType(), request.title(), request.dueDate(),
                request.dueMileage(), request.note(), LocalDateTime.now(clock));
        return toResponse(reminders.save(reminder), vehicle.getMileage());
    }

    @Transactional
    public ReminderResponse setCompleted(Long vehicleId, Long reminderId,
                                         boolean completed, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireActiveVehicle(vehicleId, user);
        VehicleReminder reminder = require(reminderId, vehicle.getId());
        if (completed) reminder.complete(LocalDateTime.now(clock));
        else reminder.reopen(LocalDateTime.now(clock));
        return toResponse(reminders.save(reminder), vehicle.getMileage());
    }

    @Transactional
    public void delete(Long vehicleId, Long reminderId, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireActiveVehicle(vehicleId, user);
        VehicleReminder reminder = require(reminderId, vehicle.getId());
        notifications.detachReminder(reminder.getId());
        reminders.delete(reminder);
    }

    private VehicleReminder require(Long reminderId, Long vehicleId) {
        return reminders.findByIdAndVehicleId(reminderId, vehicleId)
                .orElseThrow(() -> new ResourceNotFoundException("Hatırlatma bulunamadı."));
    }

    private void validate(ReminderRequest request) {
        if (request.dueDate() == null && request.dueMileage() == null) {
            throw new IllegalArgumentException("Hatırlatma için tarih veya kilometre girilmelidir.");
        }
        if (request.reminderType() == ReminderType.CUSTOM
                && (request.title() == null || request.title().isBlank())) {
            throw new IllegalArgumentException("Özel hatırlatma başlığı zorunludur.");
        }
    }

    ReminderResponse toResponse(VehicleReminder reminder, int currentMileage) {
        LocalDate today = LocalDate.now(clock);
        Integer days = reminder.getDueDate() == null ? null
                : Math.toIntExact(ChronoUnit.DAYS.between(today, reminder.getDueDate()));
        Integer kilometers = reminder.getDueMileage() == null ? null
                : reminder.getDueMileage() - currentMileage;
        String status;
        if (reminder.getCompletedAt() != null) status = "COMPLETED";
        else if ((days != null && days < 0) || (kilometers != null && kilometers < 0)) status = "OVERDUE";
        else if ((days != null && days <= DUE_SOON_DAYS)
                || (kilometers != null && kilometers <= DUE_SOON_KILOMETERS)) status = "DUE_SOON";
        else status = "UPCOMING";
        return new ReminderResponse(reminder.getId(), reminder.getVehicle().getId(),
                reminder.getReminderType(), reminder.getTitle(), reminder.getDueDate(),
                reminder.getDueMileage(), reminder.getNote(), status, days, kilometers,
                reminder.getCompletedAt(), reminder.getCreatedBy().getId(),
                reminder.getCreatedBy().getFullName());
    }
}
