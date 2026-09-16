package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.MaintenanceRequest;
import com.gorkem.vehicle_inspector.dto.response.MaintenanceResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.MaintenanceRecordRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class MaintenanceService {
    private final MaintenanceRecordRepository records;
    private final BusinessContextService businessContext;
    private final VehicleAccessService vehicleAccess;
    private final Clock clock;

    public MaintenanceService(MaintenanceRecordRepository records,
                              BusinessContextService businessContext,
                              VehicleAccessService vehicleAccess, Clock clock) {
        this.records = records; this.businessContext = businessContext;
        this.vehicleAccess = vehicleAccess; this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<MaintenanceResponse> list(Long vehicleId, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireVehicleIncludingArchived(vehicleId, user);
        return records.findAllByVehicleIdOrderByMaintenanceDateDescIdDesc(vehicle.getId())
                .stream().map(this::toResponse).toList();
    }

    @Transactional
    public MaintenanceResponse create(Long vehicleId, MaintenanceRequest request, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireActiveVehicle(vehicleId, user);
        validate(request);
        LocalDateTime now = LocalDateTime.now(clock);
        return toResponse(records.save(new MaintenanceRecord(vehicle, user,
                request.maintenanceType(), request.maintenanceDate(), request.mileage(),
                request.cost(), request.note(), request.nextRecommendedDate(),
                request.nextRecommendedMileage(), now)));
    }

    @Transactional
    public MaintenanceResponse update(Long vehicleId, Long recordId,
                                      MaintenanceRequest request, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireActiveVehicle(vehicleId, user);
        MaintenanceRecord record = records.findByIdAndVehicleId(recordId, vehicle.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Bakım kaydı bulunamadı."));
        validate(request);
        record.update(request.maintenanceType(), request.maintenanceDate(), request.mileage(),
                request.cost(), request.note(), request.nextRecommendedDate(),
                request.nextRecommendedMileage(), LocalDateTime.now(clock));
        return toResponse(records.save(record));
    }

    @Transactional
    public void delete(Long vehicleId, Long recordId, String email) {
        User user = businessContext.requireUser(email);
        Vehicle vehicle = vehicleAccess.requireActiveVehicle(vehicleId, user);
        MaintenanceRecord record = records.findByIdAndVehicleId(recordId, vehicle.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Bakım kaydı bulunamadı."));
        records.delete(record);
    }

    private void validate(MaintenanceRequest request) {
        if (request.nextRecommendedMileage() != null
                && request.nextRecommendedMileage() < request.mileage()) {
            throw new IllegalArgumentException("Sonraki bakım kilometresi mevcut bakım kilometresinden küçük olamaz.");
        }
        if (request.nextRecommendedDate() != null
                && request.nextRecommendedDate().isBefore(request.maintenanceDate())) {
            throw new IllegalArgumentException("Sonraki bakım tarihi bakım tarihinden önce olamaz.");
        }
    }

    MaintenanceResponse toResponse(MaintenanceRecord record) {
        return new MaintenanceResponse(record.getId(), record.getVehicle().getId(),
                record.getMaintenanceType(), record.getMaintenanceDate(), record.getMileage(),
                record.getCost(), record.getNote(), record.getNextRecommendedDate(),
                record.getNextRecommendedMileage(), record.getCreatedBy().getId(),
                record.getCreatedBy().getFullName(), record.getCreatedAt());
    }
}
