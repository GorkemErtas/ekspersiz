package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.PasswordResetCode;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PasswordResetCodeRepository
        extends JpaRepository<PasswordResetCode, Long> {

    Optional<PasswordResetCode> findByUserId(Long userId);

    void deleteByUserId(Long userId);
}