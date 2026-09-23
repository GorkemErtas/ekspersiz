package com.gorkem.vehicle_inspector.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.*;
import com.gorkem.vehicle_inspector.entity.AppNotification;
import com.gorkem.vehicle_inspector.entity.DeviceToken;
import com.gorkem.vehicle_inspector.repository.DeviceTokenRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.ObjectProvider;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@Service
public class FcmPushService {
    private static final Logger log = LoggerFactory.getLogger(FcmPushService.class);
    private final DeviceTokenRepository tokens;
    private final Clock clock;
    private final boolean enabled;
    private final FirebaseMessaging messaging;

    public FcmPushService(
            DeviceTokenRepository tokens,
            Clock clock,
            ObjectProvider<FirebaseApp> firebaseAppProvider,
            @Value("${application.notifications.fcm.enabled:false}")
            boolean enabled
    ) {
        this.tokens = tokens;
        this.clock = clock;
        this.enabled = enabled;

        FirebaseApp firebaseApp = firebaseAppProvider.getIfAvailable();
        this.messaging = firebaseApp == null
                ? null
                : FirebaseMessaging.getInstance(firebaseApp);
    }

    public void send(AppNotification notification) {
        if (!enabled || messaging == null) {
            return;
        }
        Map<String, String> data = new HashMap<>();
        data.put("notificationId", notification.getId().toString());
        if (notification.getNavigationTarget() != null) {
            data.put("navigationTarget", notification.getNavigationTarget());
        }
        for (DeviceToken token : tokens.findAllByUserIdAndActiveTrue(notification.getUser().getId())) {
            Message message = Message.builder()
                    .setToken(token.getToken())
                    .setNotification(Notification.builder()
                            .setTitle(notification.getTitle())
                            .setBody(notification.getBody())
                            .build())
                    .putAllData(data)
                    .build();
            try {
                messaging.send(message);
            } catch (FirebaseMessagingException exception) {
                MessagingErrorCode code = exception.getMessagingErrorCode();
                if (code == MessagingErrorCode.UNREGISTERED
                        || code == MessagingErrorCode.INVALID_ARGUMENT) {
                    token.deactivate(LocalDateTime.now(clock));
                    tokens.save(token);
                } else {
                    log.warn("FCM delivery failed for notification {}.", notification.getId(), exception);
                }
            }
        }
    }
}
