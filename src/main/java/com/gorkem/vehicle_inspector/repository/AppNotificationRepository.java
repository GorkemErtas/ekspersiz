package com.gorkem.vehicle_inspector.repository;

import com.gorkem.vehicle_inspector.entity.AppNotification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface AppNotificationRepository extends JpaRepository<AppNotification, Long> {
    List<AppNotification> findTop100ByUserIdOrderByCreatedAtDesc(Long userId);
    List<AppNotification> findTop100ByUserIdAndReadAtIsNullOrderByCreatedAtDesc(Long userId);
    Optional<AppNotification> findByIdAndUserId(Long id, Long userId);
    long countByUserIdAndReadAtIsNull(Long userId);
    boolean existsByUserIdAndEventKey(Long userId, String eventKey);

    @Modifying
    @Query("update AppNotification notification " +
            "set notification.readAt = :readAt " +
            "where notification.user.id = :userId and notification.readAt is null")
    int markAllRead(@Param("userId") Long userId,
                    @Param("readAt") LocalDateTime readAt);

    @Modifying
    @Query("update AppNotification notification " +
            "set notification.reminderId = null " +
            "where notification.reminderId = :reminderId")
    int detachReminder(@Param("reminderId") Long reminderId);
}
