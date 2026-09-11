package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.DamageInspection;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface DamageInspectionRepository
        extends JpaRepository<DamageInspection, Long> {

    List<DamageInspection>
    findAllByUserIdOrderByCreatedAtDesc(
            Long userId
    );

    Optional<DamageInspection>
    findByIdAndUserId(
            Long id,
            Long userId
    );

    List<DamageInspection>
    findAllByVehicleIdAndUserIdOrderByCreatedAtDesc(
            Long vehicleId,
            Long userId
    );

    long countByUserIdAndAnalysisStartedAtGreaterThanEqualAndAnalysisStartedAtLessThan(
            Long userId,
            LocalDateTime start,
            LocalDateTime end
    );
}