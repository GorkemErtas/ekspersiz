package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.VehicleMileageRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface VehicleMileageRecordRepository extends JpaRepository<VehicleMileageRecord, Long> {
    List<VehicleMileageRecord> findAllByVehicleIdOrderByRecordedAtDesc(Long vehicleId);
    void deleteAllByVehicleId(Long vehicleId);
}
