package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.DamageInspection;
import com.gorkem.vehicle_inspector.entity.InspectionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.domain.Pageable;
import jakarta.persistence.LockModeType;

import java.util.List;
import java.util.Optional;

public interface DamageInspectionRepository
        extends JpaRepository<DamageInspection, Long> {

    List<DamageInspection>
    findAllByVehicleUserIdAndVehicleBusinessAccountIsNullOrderByCreatedAtDesc(
            Long userId
    );

    List<DamageInspection>
    findAllByVehicleBusinessAccountIdOrderByCreatedAtDesc(
            Long businessAccountId
    );

    List<DamageInspection> findAllByVehicleIdOrderByCreatedAtDesc(Long vehicleId);

    Optional<DamageInspection> findFirstByVehicleIdAndStatusOrderByCompletedAtDesc(
            Long vehicleId, InspectionStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select i from DamageInspection i where i.id = :id")
    Optional<DamageInspection> findByIdForUpdate(@Param("id") Long id);

    @Query("""
        select i from DamageInspection i
        where i.vehicle.user.id = :userId
          and i.vehicle.businessAccount is null
          and i.status <> :processingStatus
        order by i.createdAt desc, i.id desc
        """)
    List<DamageInspection> findPersonalInspectionsForRetention(
            @Param("userId") Long userId,
            @Param("processingStatus") InspectionStatus processingStatus,
            Pageable pageable
    );

    @Query("""
        select i from DamageInspection i
        where i.vehicle.businessAccount.id = :businessAccountId
          and i.status <> :processingStatus
        order by i.createdAt desc, i.id desc
        """)
    List<DamageInspection> findBusinessInspectionsForRetention(
            @Param("businessAccountId") Long businessAccountId,
            @Param("processingStatus") InspectionStatus processingStatus,
            Pageable pageable
    );
}
