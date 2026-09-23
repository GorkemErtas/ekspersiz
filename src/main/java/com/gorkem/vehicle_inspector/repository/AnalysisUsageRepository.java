package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.AnalysisUsage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;

public interface AnalysisUsageRepository
        extends JpaRepository<AnalysisUsage, Long> {

    long countByUser_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
            Long userId,
            LocalDateTime start,
            LocalDateTime end
    );

    long countByBusinessAccount_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
            Long businessAccountId,
            LocalDateTime start,
            LocalDateTime end
    );
}