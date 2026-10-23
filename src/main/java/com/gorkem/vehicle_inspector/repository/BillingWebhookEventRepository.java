package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.BillingWebhookEvent;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BillingWebhookEventRepository
        extends JpaRepository<BillingWebhookEvent, Long> {

    boolean existsByProviderEventIdAndEnvironmentIn(String providerEventId, java.util.Collection<String> environments);
}
