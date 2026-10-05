package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.AiAssistantDailyUsage;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.Optional;

public interface AiAssistantDailyUsageRepository extends JpaRepository<AiAssistantDailyUsage, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from AiAssistantDailyUsage u where u.user.id = :userId and u.usageDate = :date")
    Optional<AiAssistantDailyUsage> findForUpdate(@Param("userId") Long userId, @Param("date") LocalDate date);
}
