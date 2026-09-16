package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.request.DeviceTokenRequest;
import com.gorkem.vehicle_inspector.dto.response.NotificationResponse;
import com.gorkem.vehicle_inspector.dto.response.UnreadCountResponse;
import com.gorkem.vehicle_inspector.service.DeviceTokenService;
import com.gorkem.vehicle_inspector.service.NotificationService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {
    private final NotificationService notifications;
    private final DeviceTokenService deviceTokens;

    public NotificationController(NotificationService notifications,
                                  DeviceTokenService deviceTokens) {
        this.notifications = notifications;
        this.deviceTokens = deviceTokens;
    }

    @GetMapping
    public List<NotificationResponse> list(
            @RequestParam(defaultValue = "false") boolean unreadOnly,
            Authentication authentication) {
        return notifications.list(authentication.getName(), unreadOnly);
    }

    @GetMapping("/unread-count")
    public UnreadCountResponse unreadCount(Authentication authentication) {
        return notifications.unreadCount(authentication.getName());
    }

    @PutMapping("/{id}/read")
    public NotificationResponse markRead(@PathVariable Long id,
                                         Authentication authentication) {
        return notifications.markRead(id, authentication.getName());
    }

    @PutMapping("/read-all")
    public ResponseEntity<Void> markAllRead(Authentication authentication) {
        notifications.markAllRead(authentication.getName());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/devices")
    public ResponseEntity<Void> registerDevice(@Valid @RequestBody DeviceTokenRequest request,
                                               Authentication authentication) {
        deviceTokens.register(request, authentication.getName());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/devices")
    public ResponseEntity<Void> unregisterDevice(@RequestParam String token,
                                                 Authentication authentication) {
        deviceTokens.unregister(token, authentication.getName());
        return ResponseEntity.noContent().build();
    }
}
