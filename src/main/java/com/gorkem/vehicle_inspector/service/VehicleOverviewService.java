package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.mapper.VehicleMapper;
import com.gorkem.vehicle_inspector.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@Service
public class VehicleOverviewService {
    private final BusinessContextService businessContext;
    private final VehicleAccessService vehicleAccess;
    private final MaintenanceRecordRepository maintenance;
    private final VehicleReminderRepository reminders;
    private final VehicleMileageRecordRepository mileageRecords;
    private final DamageInspectionRepository inspections;
    private final MaintenanceService maintenanceService;
    private final ReminderService reminderService;

    public VehicleOverviewService(BusinessContextService businessContext,
                                  VehicleAccessService vehicleAccess,
                                  MaintenanceRecordRepository maintenance,
                                  VehicleReminderRepository reminders,
                                  VehicleMileageRecordRepository mileageRecords,
                                  DamageInspectionRepository inspections,
                                  MaintenanceService maintenanceService,
                                  ReminderService reminderService) {
        this.businessContext = businessContext; this.vehicleAccess = vehicleAccess;
        this.maintenance = maintenance; this.reminders = reminders;
        this.mileageRecords = mileageRecords; this.inspections = inspections;
        this.maintenanceService = maintenanceService; this.reminderService = reminderService;
    }

    private String maintenanceTypeLabel(MaintenanceType type) {
        return switch (type) {
            case ENGINE_OIL -> "Motor yağı";
            case OIL_FILTER -> "Yağ filtresi";
            case AIR_FILTER -> "Hava filtresi";
            case CABIN_FILTER -> "Polen filtresi";
            case BRAKE_PADS -> "Fren balataları";
            case BRAKE_FLUID -> "Fren hidroliği";
            case BATTERY -> "Akü";
            case TIRES -> "Lastikler";
            case TIMING_SYSTEM -> "Triger / zincir";
            case TRANSMISSION -> "Şanzıman";
            case PERIODIC_MAINTENANCE -> "Periyodik bakım";
            case CUSTOM -> "Özel bakım";
        };
    }

    private String damageSeverityLabel(DamageSeverity severity) {
        return switch (severity) {
            case UNKNOWN -> "Bilinmiyor";
            case NONE -> "Hasar yok";
            case MINOR -> "Hafif";
            case MODERATE -> "Orta";
            case SEVERE -> "Ağır";
        };
    }

    @Transactional(readOnly = true)
    public VehicleOverviewResponse overview(Long vehicleId, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireActiveVehicle(vehicleId, user);
        MaintenanceResponse latestMaintenance = maintenance
                .findFirstByVehicleIdOrderByMaintenanceDateDescIdDesc(vehicleId)
                .map(maintenanceService::toResponse).orElse(null);
        List<ReminderResponse> active = reminders
                .findAllByVehicleIdAndCompletedAtIsNullOrderByDueDateAscIdAsc(vehicleId)
                .stream().map(item -> reminderService.toResponse(item, vehicle.getMileage())).toList();
        DamageInspection latest = inspections
                .findFirstByVehicleIdAndStatusOrderByCompletedAtDesc(vehicleId, InspectionStatus.COMPLETED)
                .orElse(null);
        boolean attention = active.stream().anyMatch(item -> item.status().equals("OVERDUE"))
                || latest != null && (latest.getDamageSeverity() == DamageSeverity.SEVERE
                || latest.getDamageSeverity() == DamageSeverity.MODERATE);
        boolean dueSoon = active.stream().anyMatch(item -> item.status().equals("DUE_SOON"));
        return new VehicleOverviewResponse(VehicleMapper.toResponse(vehicle),
                attention ? "ATTENTION" : dueSoon ? "DUE_SOON" : "GOOD",
                "Bu durum yalnızca kayıtlı bakım, hatırlatma ve görünür hasar verilerine dayanır; mekanik ekspertiz değildir.",
                latestMaintenance, active.stream().limit(5).toList(),
                latest == null ? null : latest.getId(),
                latest == null || latest.getDamageSeverity() == null ? null : latest.getDamageSeverity().name(),
                latest == null ? null : latest.getCompletedAt());
    }

    @Transactional(readOnly = true)
    public List<VehicleHistoryItemResponse> history(Long vehicleId, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireVehicleIncludingArchived(vehicleId, user);
        List<VehicleHistoryItemResponse> items = new ArrayList<>();
        if (vehicle.getCreatedAt() != null) {
            items.add(new VehicleHistoryItemResponse("VEHICLE_CREATED", vehicle.getId(),
                    "Araç eklendi", vehicle.getMileage() + " km", vehicle.getCreatedAt()));
        }
        mileageRecords.findAllByVehicleIdOrderByRecordedAtDesc(vehicleId).forEach(record ->
                items.add(new VehicleHistoryItemResponse("MILEAGE_UPDATED", record.getId(),
                        "Kilometre güncellendi",
                        record.getPreviousMileage() + " km → " + record.getNewMileage() + " km",
                        record.getRecordedAt())));
        maintenance.findAllByVehicleIdOrderByMaintenanceDateDescIdDesc(vehicleId).forEach(record ->
                items.add(new VehicleHistoryItemResponse(
                        "MAINTENANCE",
                        record.getId(),
                        "Bakım: " + maintenanceTypeLabel(record.getMaintenanceType()),
                        record.getMileage() + " km",
                        record.getMaintenanceDate().atStartOfDay()
                )));
        inspections.findAllByVehicleIdOrderByCreatedAtDesc(vehicleId).stream()
                .filter(item -> item.getStatus() == InspectionStatus.COMPLETED).forEach(item ->
                        items.add(new VehicleHistoryItemResponse("AI_INSPECTION", item.getId(),
                                "AI hasar analizi",
                                item.getDamageSeverity() == null
                                        ? "Sonuç kaydedildi"
                                        : damageSeverityLabel(item.getDamageSeverity()),
                                item.getCompletedAt() == null ? item.getCreatedAt() : item.getCompletedAt())));
        return items.stream().sorted(Comparator.comparing(
                        VehicleHistoryItemResponse::occurredAt,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .toList();
    }
}
