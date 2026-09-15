package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.BusinessInvitation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface BusinessInvitationRepository
        extends JpaRepository<BusinessInvitation, Long> {

    Optional<BusinessInvitation>
    findByBusinessAccountIdAndUserId(
            Long businessAccountId,
            Long userId
    );

    Optional<BusinessInvitation>
    findByUserId(Long userId);

    void deleteByUserId(Long userId);
}