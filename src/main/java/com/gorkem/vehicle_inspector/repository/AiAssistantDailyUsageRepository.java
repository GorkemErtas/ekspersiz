package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.AiAssistantDailyUsage;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.util.Optional;

public interface AiAssistantDailyUsageRepository extends JpaRepository<AiAssistantDailyUsage, Long> {
    Optional<AiAssistantDailyUsage> findByUserIdAndUsageDate(Long userId, LocalDate date);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from AiAssistantDailyUsage u where u.user.id = :userId and u.usageDate = :date")
    Optional<AiAssistantDailyUsage> findForUpdate(@Param("userId") Long userId, @Param("date") LocalDate date);

    @Modifying
    @Query(value = """
        INSERT INTO ai_assistant_daily_usage
            (user_id, usage_date, successful_questions, out_of_scope_attempts,
             created_at, updated_at)
        VALUES (:userId, :date, 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (user_id, usage_date) DO NOTHING
        """, nativeQuery = true)
    void ensureDailyRow(@Param("userId") Long userId, @Param("date") LocalDate date);
}
