package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.DeviceToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {
    Optional<DeviceToken> findByToken(String token);
    List<DeviceToken> findAllByUserIdAndActiveTrue(Long userId);
}
