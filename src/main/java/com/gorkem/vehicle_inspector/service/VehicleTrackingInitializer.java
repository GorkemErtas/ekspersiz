package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.VehicleTrackingRequest;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.MaintenanceRecordRepository;
import com.gorkem.vehicle_inspector.repository.VehicleReminderRepository;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.LocalDateTime;

@Service
public class VehicleTrackingInitializer {
    private final MaintenanceRecordRepository maintenance;
    private final VehicleReminderRepository reminders;
    private final Clock clock;

    public VehicleTrackingInitializer(MaintenanceRecordRepository maintenance,
                                      VehicleReminderRepository reminders, Clock clock) {
        this.maintenance = maintenance; this.reminders = reminders; this.clock = clock;
    }

    public void initialize(Vehicle vehicle, User user, VehicleTrackingRequest request) {
        if (request == null) return;
        LocalDateTime now = LocalDateTime.now(clock);
        vehicle.setNotes(request.notes());

        boolean hasLastDate = request.lastMaintenanceDate() != null;
        boolean hasLastMileage = request.lastMaintenanceMileage() != null;
        if (hasLastDate != hasLastMileage) {
            throw new IllegalArgumentException("Son bakım tarihi ve kilometresi birlikte girilmelidir.");
        }
        if (hasLastDate) {
            maintenance.save(new MaintenanceRecord(vehicle, user,
                    MaintenanceType.PERIODIC_MAINTENANCE,
                    request.lastMaintenanceDate(), request.lastMaintenanceMileage(),
                    null, null, request.nextMaintenanceDate(),
                    request.nextMaintenanceMileage(), now));
        } else if (request.nextMaintenanceDate() != null || request.nextMaintenanceMileage() != null) {
            saveReminder(vehicle, user, ReminderType.PERIODIC_MAINTENANCE,
                    request.nextMaintenanceDate(), request.nextMaintenanceMileage(), now);
        }

        saveReminder(vehicle, user, ReminderType.VEHICLE_INSPECTION,
                request.vehicleInspectionDate(), null, now);
        saveReminder(vehicle, user, ReminderType.TRAFFIC_INSURANCE,
                request.trafficInsuranceExpiryDate(), null, now);
        saveReminder(vehicle, user, ReminderType.COMPREHENSIVE_INSURANCE,
                request.comprehensiveInsuranceExpiryDate(), null, now);
        saveReminder(vehicle, user, ReminderType.TIRE_CHECK,
                request.tireCheckDate(), null, now);
    }

    private void saveReminder(Vehicle vehicle, User user, ReminderType type,
                              java.time.LocalDate date, Integer mileage, LocalDateTime now) {
        if (date == null && mileage == null) return;
        reminders.save(new VehicleReminder(vehicle, user, type, null, date, mileage, null, now));
    }
}
