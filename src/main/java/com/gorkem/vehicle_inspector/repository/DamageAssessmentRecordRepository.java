package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.DamageAssessmentRecord;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface DamageAssessmentRecordRepository
        extends JpaRepository<DamageAssessmentRecord, Long> {

    Optional<DamageAssessmentRecord> findByInspectionId(Long inspectionId);

    boolean existsByInspectionId(Long inspectionId);

    boolean existsByRecordNumber(String recordNumber);
}
