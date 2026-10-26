package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.NotificationResponse;
import com.gorkem.vehicle_inspector.dto.response.UnreadCountResponse;
import com.gorkem.vehicle_inspector.entity.AppNotification;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.AppNotificationRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class NotificationService {
    private final AppNotificationRepository notifications;
    private final BusinessContextService businessContext;
    private final Clock clock;

    public NotificationService(AppNotificationRepository notifications,
                               BusinessContextService businessContext, Clock clock) {
        this.notifications = notifications;
        this.businessContext = businessContext;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> list(String email, boolean unreadOnly) {
        User user = businessContext.requireUser(email);
        var workspace = businessContext.workspace(user);
        List<AppNotification> result = notifications.findVisible(user.getId(), workspace.businessId(), unreadOnly,
                org.springframework.data.domain.PageRequest.of(0, 100));
        return result.stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public UnreadCountResponse unreadCount(String email) {
        User user = businessContext.requireUser(email);
        return new UnreadCountResponse(notifications.countVisibleUnread(user.getId(), businessContext.workspace(user).businessId()));
    }

    @Transactional
    public NotificationResponse markRead(Long id, String email) {
        User user = businessContext.requireUser(email);
        AppNotification notification = notifications.findVisibleById(id, user.getId(), businessContext.workspace(user).businessId())
                .orElseThrow(() -> new ResourceNotFoundException("Bildirim bulunamadı."));
        notification.markRead(LocalDateTime.now(clock));
        return toResponse(notifications.save(notification));
    }

    @Transactional
    public void markAllRead(String email) {
        User user = businessContext.requireUser(email);
        notifications.markVisibleRead(user.getId(), businessContext.workspace(user).businessId(), LocalDateTime.now(clock));
    }

    private NotificationResponse toResponse(AppNotification notification) {
        return new NotificationResponse(notification.getId(),
                notification.getVehicle() == null ? null : notification.getVehicle().getId(),
                notification.getNotificationType(), notification.getSeverity(),
                notification.getTitle(), notification.getBody(),
                notification.getNavigationTarget(), notification.getReadAt() != null,
                notification.getCreatedAt());
    }
}
