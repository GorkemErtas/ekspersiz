package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.AiAssistantAccess;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface AiAssistantAccessRepository extends JpaRepository<AiAssistantAccess, Long> {
    Optional<AiAssistantAccess> findByUserId(Long userId);
}
