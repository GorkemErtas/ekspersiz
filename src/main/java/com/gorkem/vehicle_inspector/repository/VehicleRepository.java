package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface VehicleRepository
        extends JpaRepository<Vehicle, Long> {

    Optional<Vehicle> findByPlate(String plate);

    boolean existsByPlate(String plate);

    boolean existsByPlateAndIdNot(
            String plate,
            Long id
    );

    boolean existsByUserId(Long userId);

    List<Vehicle>
    findAllByUserIdAndArchivedFalseOrderByIdDesc(
            Long userId
    );

    Optional<Vehicle>
    findByIdAndUserIdAndArchivedFalse(
            Long id,
            Long userId
    );

    Optional<Vehicle>
    findByUserIdAndPrimaryVehicleTrueAndArchivedFalse(
            Long userId
    );

    long countByUserIdAndArchivedFalse(
            Long userId
    );

    List<Vehicle>
    findAllByBusinessAccountIdAndArchivedFalseOrderByIdDesc(
            Long businessAccountId
    );

    Optional<Vehicle>
    findByIdAndBusinessAccountIdAndArchivedFalse(
            Long id,
            Long businessAccountId
    );

    Optional<Vehicle>
    findByBusinessAccountIdAndPrimaryVehicleTrueAndArchivedFalse(
            Long businessAccountId
    );

    long countByBusinessAccountIdAndArchivedFalse(
            Long businessAccountId
    );

    List<Vehicle> findAllByUserId(Long userId);
}
