package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusinessAccountRepository
        extends JpaRepository<BusinessAccount, Long> {
}