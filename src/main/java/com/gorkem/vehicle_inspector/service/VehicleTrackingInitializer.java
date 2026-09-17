package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.VehicleTrackingRequest;
import com.gorkem.vehicle_inspector.dto.request.MaintenanceRequest;
import com.gorkem.vehicle_inspector.dto.request.ReminderRequest;
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
    private final ReminderScheduleCalculator calculator;
    private final Clock clock;

    public VehicleTrackingInitializer(MaintenanceRecordRepository maintenance,
                                      VehicleReminderRepository reminders,
                                      ReminderScheduleCalculator calculator, Clock clock) {
        this.maintenance = maintenance; this.reminders = reminders;
        this.calculator = calculator; this.clock = clock;
    }

    public void initialize(Vehicle vehicle, User user, VehicleTrackingRequest request) {
        if (request == null) return;
        LocalDateTime now = LocalDateTime.now(clock);
        vehicle.setNotes(request.notes());

        boolean hasLastDate = request.lastMaintenanceDate() != null;
        boolean hasLastMileage = request.lastMaintenanceMileage() != null;
        boolean hasInterval = request.maintenanceIntervalMonths() != null
                || request.maintenanceIntervalMileage() != null;
        if (hasInterval) {
            ReminderRequest reminderRequest = new ReminderRequest(
                    ReminderType.PERIODIC_MAINTENANCE, null,
                    request.nextMaintenanceDate(), request.nextMaintenanceMileage(), null,
                    request.lastMaintenanceDate(), request.lastMaintenanceMileage(),
                    request.maintenanceIntervalMonths(), request.maintenanceIntervalMileage(), null);
            ReminderScheduleCalculator.Schedule reminderSchedule =
                    calculator.calculate(vehicle, reminderRequest);
            saveReminder(vehicle, user, ReminderType.PERIODIC_MAINTENANCE,
                    reminderSchedule.dueDate(), reminderSchedule.dueMileage(),
                    reminderSchedule.sourceDate(), reminderSchedule.sourceMileage(),
                    reminderSchedule.intervalMonths(), reminderSchedule.intervalMileage(),
                    null, now);

            // A maintenance history entry requires both event date and mileage. A reminder can
            // still be calculated from only the source required by its selected interval.
            if (hasLastDate && hasLastMileage) {
                ReminderScheduleCalculator.MaintenanceSchedule maintenanceSchedule =
                        calculator.calculateMaintenance(new MaintenanceRequest(
                                MaintenanceType.PERIODIC_MAINTENANCE,
                                request.lastMaintenanceDate(), request.lastMaintenanceMileage(),
                                null, null, null, null,
                                request.maintenanceIntervalMonths(),
                                request.maintenanceIntervalMileage()));
                maintenance.save(new MaintenanceRecord(vehicle, user,
                        MaintenanceType.PERIODIC_MAINTENANCE,
                        request.lastMaintenanceDate(), request.lastMaintenanceMileage(),
                        null, null, maintenanceSchedule.nextDate(), maintenanceSchedule.nextMileage(),
                        maintenanceSchedule.intervalMonths(), maintenanceSchedule.intervalMileage(), now));
            }
        } else if (hasLastDate || hasLastMileage) {
            if (hasLastDate != hasLastMileage) {
                throw new IllegalArgumentException(
                        "Aralık olmadan bakım kaydı oluşturmak için tarih ve kilometre birlikte girilmelidir.");
            }
            MaintenanceRequest maintenanceRequest = new MaintenanceRequest(
                    MaintenanceType.PERIODIC_MAINTENANCE,
                    request.lastMaintenanceDate(), request.lastMaintenanceMileage(),
                    null, null, request.nextMaintenanceDate(), request.nextMaintenanceMileage(),
                    request.maintenanceIntervalMonths(), request.maintenanceIntervalMileage());
            ReminderScheduleCalculator.MaintenanceSchedule schedule =
                    calculator.calculateMaintenance(maintenanceRequest);
            maintenance.save(new MaintenanceRecord(vehicle, user,
                    MaintenanceType.PERIODIC_MAINTENANCE,
                    request.lastMaintenanceDate(), request.lastMaintenanceMileage(),
                    null, null, schedule.nextDate(), schedule.nextMileage(),
                    schedule.intervalMonths(), schedule.intervalMileage(), now));
            saveReminder(vehicle, user, ReminderType.PERIODIC_MAINTENANCE,
                    schedule.nextDate(), schedule.nextMileage(),
                    null, null, null, null, null, now);
        } else if (request.nextMaintenanceDate() != null || request.nextMaintenanceMileage() != null) {
            saveReminder(vehicle, user, ReminderType.PERIODIC_MAINTENANCE,
                    request.nextMaintenanceDate(), request.nextMaintenanceMileage(),
                    null, null, null, null, null, now);
        }

        if (request.vehicleInspectionDate() != null || request.inspectionReferenceDate() != null
                || Boolean.TRUE.equals(request.firstInspection())) {
            ReminderRequest inspectionRequest = new ReminderRequest(
                    ReminderType.VEHICLE_INSPECTION, null,
                    request.vehicleInspectionDate(), null, null,
                    request.inspectionReferenceDate(), null, null, null,
                    request.firstInspection());
            ReminderScheduleCalculator.Schedule inspection =
                    calculator.calculate(vehicle, inspectionRequest);
            saveReminder(vehicle, user, ReminderType.VEHICLE_INSPECTION,
                    inspection.dueDate(), null, inspection.sourceDate(), null,
                    null, null, inspection.firstInspection(), now);
        }
        saveReminder(vehicle, user, ReminderType.TRAFFIC_INSURANCE,
                request.trafficInsuranceExpiryDate(), null,
                null, null, null, null, null, now);
        saveReminder(vehicle, user, ReminderType.COMPREHENSIVE_INSURANCE,
                request.comprehensiveInsuranceExpiryDate(), null,
                null, null, null, null, null, now);
        saveReminder(vehicle, user, ReminderType.TIRE_CHECK,
                request.tireCheckDate(), null,
                null, null, null, null, null, now);
    }

    private void saveReminder(Vehicle vehicle, User user, ReminderType type,
                              java.time.LocalDate date, Integer mileage,
                              java.time.LocalDate sourceDate, Integer sourceMileage,
                              Integer intervalMonths, Integer intervalMileage,
                              Boolean firstInspection, LocalDateTime now) {
        if (date == null && mileage == null) return;
        reminders.save(new VehicleReminder(vehicle, user, type, null, date, mileage, null,
                sourceDate, sourceMileage, intervalMonths, intervalMileage,
                firstInspection, now));
    }
}
