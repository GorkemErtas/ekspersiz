package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.AiAssistantQuotaReservation;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

public interface AiAssistantQuotaReservationRepository
        extends JpaRepository<AiAssistantQuotaReservation, UUID> {

    @Query("""
        select count(r) from AiAssistantQuotaReservation r
        where r.user.id = :userId
          and r.usageDate = :date
          and r.status = 'RESERVED'
          and r.expiresAt > :now
        """)
    long countActive(@Param("userId") Long userId,
                     @Param("date") LocalDate date,
                     @Param("now") LocalDateTime now);

    @Modifying
    @Query("""
        update AiAssistantQuotaReservation r
        set r.status = 'RELEASED', r.releasedAt = :now
        where r.status = 'RESERVED' and r.expiresAt <= :now
        """)
    int releaseExpired(@Param("now") LocalDateTime now);
}
