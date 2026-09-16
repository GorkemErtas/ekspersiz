package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface BusinessMemberRepository
        extends JpaRepository<BusinessMember, Long> {

    @EntityGraph(attributePaths = "businessAccount")
    Optional<BusinessMember> findByUserId(Long userId);

    List<BusinessMember> findByBusinessAccountId(
            Long businessAccountId
    );

    @EntityGraph(attributePaths = "user")
    List<BusinessMember>
    findAllByBusinessAccountIdAndRoleOrderByUserFullNameAsc(
            Long businessAccountId,
            BusinessRole role
    );

    Optional<BusinessMember> findByIdAndBusinessAccountId(
            Long id,
            Long businessAccountId
    );

    boolean existsByUserId(Long userId);
}
