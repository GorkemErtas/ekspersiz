package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.AnalysisCreditTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AnalysisCreditTransactionRepository
        extends JpaRepository<AnalysisCreditTransaction, Long> {

    boolean existsByExternalTransactionId(String externalTransactionId);

    @Query("select coalesce(sum(t.amount), 0) from AnalysisCreditTransaction t where t.user.id = :userId")
    long balanceByUserId(@Param("userId") Long userId);
}
