package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.PendingRegistration;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface PendingRegistrationRepository
        extends JpaRepository<PendingRegistration, Long> {

    Optional<PendingRegistration> findByEmail(String email);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select registration
            from PendingRegistration registration
            where registration.email = :email
            """)
    Optional<PendingRegistration> findByEmailForUpdate(
            @Param("email") String email
    );
}
