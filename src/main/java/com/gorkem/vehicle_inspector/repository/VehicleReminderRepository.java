package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.VehicleReminder;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface VehicleReminderRepository extends JpaRepository<VehicleReminder, Long> {
    List<VehicleReminder> findAllByCompletedAtIsNull();
    List<VehicleReminder> findAllByVehicleIdOrderByCompletedAtAscDueDateAscIdDesc(Long vehicleId);
    List<VehicleReminder> findAllByVehicleIdAndCompletedAtIsNullOrderByDueDateAscIdAsc(Long vehicleId);
    Optional<VehicleReminder> findByIdAndVehicleId(Long id, Long vehicleId);
    void deleteAllByVehicleId(Long vehicleId);
}
