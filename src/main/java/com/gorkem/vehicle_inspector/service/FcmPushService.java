package com.gorkem.vehicle_inspector.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.*;
import com.gorkem.vehicle_inspector.entity.AppNotification;
import com.gorkem.vehicle_inspector.entity.DeviceToken;
import com.gorkem.vehicle_inspector.repository.DeviceTokenRepository;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.FileInputStream;
import java.io.IOException;
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
    private final String credentialsPath;
    private FirebaseMessaging messaging;

    public FcmPushService(DeviceTokenRepository tokens, Clock clock,
                          @Value("${application.notifications.fcm.enabled:false}") boolean enabled,
                          @Value("${application.notifications.fcm.credentials-path:}") String credentialsPath) {
        this.tokens = tokens;
        this.clock = clock;
        this.enabled = enabled;
        this.credentialsPath = credentialsPath;
    }

    @PostConstruct
    void initialize() {
        if (!enabled) return;
        try {
            GoogleCredentials credentials = credentialsPath.isBlank()
                    ? GoogleCredentials.getApplicationDefault()
                    : GoogleCredentials.fromStream(new FileInputStream(credentialsPath));
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(credentials)
                    .build();
            FirebaseApp app = FirebaseApp.getApps().stream()
                    .filter(candidate -> candidate.getName().equals("vehicle-inspector"))
                    .findFirst()
                    .orElseGet(() -> FirebaseApp.initializeApp(options, "vehicle-inspector"));
            messaging = FirebaseMessaging.getInstance(app);
        } catch (IOException | RuntimeException exception) {
            log.error("FCM could not be initialized; push delivery is disabled.", exception);
        }
    }

    public void send(AppNotification notification) {
        if (messaging == null) return;
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
