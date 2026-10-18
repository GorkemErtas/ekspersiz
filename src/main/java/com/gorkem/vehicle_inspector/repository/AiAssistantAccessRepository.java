package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.AiAssistantAccess;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface AiAssistantAccessRepository extends JpaRepository<AiAssistantAccess, Long> {
    Optional<AiAssistantAccess> findByUserId(Long userId);

    @Modifying
    @Query(value = "DELETE FROM ai_assistant_access WHERE user_id = :userId", nativeQuery = true)
    int deleteAllByUserId(@Param("userId") Long userId);
}
