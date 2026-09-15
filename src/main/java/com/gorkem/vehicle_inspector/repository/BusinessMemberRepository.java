package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.BusinessMember;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface BusinessMemberRepository
        extends JpaRepository<BusinessMember, Long> {

    Optional<BusinessMember> findByUserId(Long userId);

    List<BusinessMember> findByBusinessAccountId(
            Long businessAccountId
    );

    boolean existsByUserId(Long userId);
}