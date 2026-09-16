package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.RewardedAnalysisSession;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Optional;

public interface RewardedAnalysisSessionRepository
        extends JpaRepository<RewardedAnalysisSession, Long> {
    Optional<RewardedAnalysisSession> findByUserIdAndMonthStart(Long userId, LocalDate monthStart);

    boolean existsByUserIdAndMonthStartAndClaimedAtIsNotNull(Long userId, LocalDate monthStart);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from RewardedAnalysisSession r join fetch r.user where r.token = :token")
    Optional<RewardedAnalysisSession> findByTokenForUpdate(@Param("token") String token);

    boolean existsByTransactionId(String transactionId);
}
