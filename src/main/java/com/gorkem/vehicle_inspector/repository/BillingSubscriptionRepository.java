package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.BillingSubscription;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface BillingSubscriptionRepository
        extends JpaRepository<BillingSubscription, Long> {

    Optional<BillingSubscription> findByUserId(Long userId);
}
