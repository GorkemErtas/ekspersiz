package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.MaintenanceRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface MaintenanceRecordRepository extends JpaRepository<MaintenanceRecord, Long> {
    List<MaintenanceRecord> findAllByVehicleIdOrderByMaintenanceDateDescIdDesc(Long vehicleId);
    Optional<MaintenanceRecord> findByIdAndVehicleId(Long id, Long vehicleId);
    Optional<MaintenanceRecord> findFirstByVehicleIdOrderByMaintenanceDateDescIdDesc(Long vehicleId);
}
