package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.Optional;

public interface BusinessAccountRepository
        extends JpaRepository<BusinessAccount, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select b from BusinessAccount b where b.id = :id")
    Optional<BusinessAccount> findByIdForUpdate(@Param("id") Long id);
}
