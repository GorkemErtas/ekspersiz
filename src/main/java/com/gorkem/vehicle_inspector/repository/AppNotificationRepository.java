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
    String VISIBLE = "n.user.id = :userId and ((:businessId is null and n.vehicle is null) or n.vehicle.id in "
            + "(select v.id from Vehicle v where (:businessId is null and v.user.id = :userId and v.businessAccount is null) "
            + "or (v.businessAccount.id = :businessId and exists (select m.id from BusinessMember m "
            + "where m.user.id = :userId and m.businessAccount.id = :businessId))))";

    @Query("select n from AppNotification n where " + VISIBLE + " and (:unreadOnly = false or n.readAt is null) order by n.createdAt desc")
    List<AppNotification> findVisible(@Param("userId") Long userId, @Param("businessId") Long businessId,
                                      @Param("unreadOnly") boolean unreadOnly, org.springframework.data.domain.Pageable pageable);

    @Query("select n from AppNotification n where n.id = :id and " + VISIBLE)
    Optional<AppNotification> findVisibleById(@Param("id") Long id, @Param("userId") Long userId, @Param("businessId") Long businessId);

    @Query("select count(n) from AppNotification n where n.readAt is null and " + VISIBLE)
    long countVisibleUnread(@Param("userId") Long userId, @Param("businessId") Long businessId);

    @Modifying
    @Query("update AppNotification n set n.readAt = :readAt where n.readAt is null and " + VISIBLE)
    int markVisibleRead(@Param("userId") Long userId, @Param("businessId") Long businessId, @Param("readAt") LocalDateTime readAt);
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

    void deleteAllByUserId(Long userId);
}
