package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.ReminderRequest;
import com.gorkem.vehicle_inspector.dto.request.MaintenanceRequest;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import org.springframework.stereotype.Service;

import java.time.LocalDate;

@Service
public class ReminderScheduleCalculator {
    public MaintenanceSchedule calculateMaintenance(MaintenanceRequest request) {
        boolean calculated = request.intervalMonths() != null || request.intervalMileage() != null;
        if (calculated && (request.nextRecommendedDate() != null
                || request.nextRecommendedMileage() != null)) {
            throw new IllegalArgumentException(
                    "Bakım aralığı ile manuel sonraki bakım hedefi aynı anda girilemez.");
        }
        LocalDate nextDate = request.nextRecommendedDate();
        Integer nextMileage = request.nextRecommendedMileage();
        if (request.intervalMonths() != null) {
            nextDate = request.maintenanceDate().plusMonths(request.intervalMonths());
        }
        if (request.intervalMileage() != null) {
            nextMileage = Math.addExact(request.mileage(), request.intervalMileage());
            if (nextMileage > 2_000_000) {
                throw new IllegalArgumentException("Hesaplanan bakım kilometresi geçerli aralığı aşıyor.");
            }
        }
        return new MaintenanceSchedule(nextDate, nextMileage,
                request.intervalMonths(), request.intervalMileage());
    }

    public Schedule calculate(Vehicle vehicle, ReminderRequest request) {
        return switch (request.reminderType()) {
            case VEHICLE_INSPECTION -> inspection(vehicle, request);
            case TRAFFIC_INSURANCE, COMPREHENSIVE_INSURANCE -> policy(request);
            case PERIODIC_MAINTENANCE -> maintenance(vehicle, request);
            case TIRE_CHECK, CUSTOM -> manual(request);
        };
    }

    private Schedule inspection(Vehicle vehicle, ReminderRequest request) {
        rejectMileage(request, "Araç muayenesi");
        if (request.sourceDate() != null) {
            if (request.dueDate() != null) {
                throw new IllegalArgumentException(
                        "Son muayene tarihi ile manuel muayene tarihi aynı anda girilemez."
                );
            }

            boolean firstInspection =
                    Boolean.TRUE.equals(request.firstInspection());

            LocalDate nextInspectionDate = firstInspection
                    ? request.sourceDate().plusYears(3)
                    : request.sourceDate().plusYears(2);

            return new Schedule(
                    nextInspectionDate,
                    null,
                    request.sourceDate(),
                    null,
                    null,
                    null,
                    firstInspection
            );
        }

        if (Boolean.TRUE.equals(request.firstInspection())) {
            throw new IllegalArgumentException(
                    "İlk muayene seçildiyse son araç muayene tarihi girilmelidir."
            );
        }

        if (request.dueDate() != null) {
            return manual(request);
        }

        throw new IllegalArgumentException(
                "Son araç muayene tarihi girilmelidir."
        );
    }

    private Schedule policy(ReminderRequest request) {
        rejectCalculationInputs(request, "Sigorta hatırlatması");
        rejectMileage(request, "Sigorta hatırlatması");
        if (request.dueDate() == null) {
            throw new IllegalArgumentException("Poliçe bitiş tarihi zorunludur.");
        }
        return manual(request);
    }

    private Schedule maintenance(Vehicle vehicle, ReminderRequest request) {
        boolean calculated = request.sourceDate() != null || request.sourceMileage() != null
                || request.intervalMonths() != null || request.intervalMileage() != null;
        rejectMixedManualAndCalculated(request, calculated);
        if (!calculated) return manual(request);

        if (request.intervalMonths() == null && request.intervalMileage() == null) {
            throw new IllegalArgumentException("Bakım için ay veya kilometre aralığı girilmelidir.");
        }
        LocalDate dueDate = null;
        if (request.intervalMonths() != null) {
            if (request.sourceDate() == null) {
                throw new IllegalArgumentException("Ay aralığı için son bakım tarihi gereklidir.");
            }
            dueDate = request.sourceDate().plusMonths(request.intervalMonths());
        }
        Integer dueMileage = null;
        if (request.intervalMileage() != null) {
            if (request.sourceMileage() == null) {
                throw new IllegalArgumentException("Kilometre aralığı için son bakım kilometresi gereklidir.");
            }
            if (request.sourceMileage() > vehicle.getMileage()) {
                throw new IllegalArgumentException(
                        "Son bakım kilometresi aracın güncel kilometresini aşamaz.");
            }
            dueMileage = Math.addExact(request.sourceMileage(), request.intervalMileage());
            if (dueMileage > 2_000_000) {
                throw new IllegalArgumentException("Hesaplanan bakım kilometresi geçerli aralığı aşıyor.");
            }
        }
        return new Schedule(dueDate, dueMileage, request.sourceDate(), request.sourceMileage(),
                request.intervalMonths(), request.intervalMileage(), null);
    }

    private Schedule manual(ReminderRequest request) {
        rejectCalculationInputs(request, "Manuel hatırlatma");
        if (request.dueDate() == null && request.dueMileage() == null) {
            throw new IllegalArgumentException("Hatırlatma için tarih veya kilometre girilmelidir.");
        }
        return new Schedule(request.dueDate(), request.dueMileage(),
                null, null, null, null, null);
    }

    private void rejectMixedManualAndCalculated(ReminderRequest request, boolean calculated) {
        if (calculated && (request.dueDate() != null || request.dueMileage() != null)) {
            throw new IllegalArgumentException(
                    "Hesaplama kaynakları ile manuel hedef aynı anda girilemez.");
        }
    }

    private void rejectCalculationInputs(ReminderRequest request, String label) {
        if (request.sourceDate() != null || request.sourceMileage() != null
                || request.intervalMonths() != null || request.intervalMileage() != null
                || request.firstInspection() != null) {
            throw new IllegalArgumentException(label + " için ilgisiz hesaplama alanları gönderildi.");
        }
    }

    private void rejectMileage(ReminderRequest request, String label) {
        if (request.dueMileage() != null || request.sourceMileage() != null
                || request.intervalMileage() != null || request.intervalMonths() != null) {
            throw new IllegalArgumentException(label + " kilometre bilgisi kullanmaz.");
        }
    }

    public record Schedule(LocalDate dueDate, Integer dueMileage,
                           LocalDate sourceDate, Integer sourceMileage,
                           Integer intervalMonths, Integer intervalMileage,
                           Boolean firstInspection) {}

    public record MaintenanceSchedule(LocalDate nextDate, Integer nextMileage,
                                      Integer intervalMonths, Integer intervalMileage) {}
}
