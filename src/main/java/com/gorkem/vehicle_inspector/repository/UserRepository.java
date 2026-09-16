package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    Optional<User> findByBillingCustomerId(String billingCustomerId);

    boolean existsByEmail(String email);
}
