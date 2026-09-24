package com.gorkem.vehicle_inspector.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

@Configuration
@ConditionalOnProperty(
        name = "application.notifications.fcm.enabled",
        havingValue = "true"
)
public class FirebaseConfig {

    private final String credentialsPath;
    private final String credentialsJson;

    public FirebaseConfig(
            @Value("${application.notifications.fcm.credentials-path:}")
            String credentialsPath,
            @Value("${application.notifications.fcm.credentials-json:}")
            String credentialsJson
    ) {
        this.credentialsPath = credentialsPath;
        this.credentialsJson = credentialsJson;
    }

    @Bean
    public FirebaseApp firebaseApp() throws IOException {
        GoogleCredentials credentials;

        if (!credentialsJson.isBlank()) {
            credentials = GoogleCredentials.fromStream(
                    new ByteArrayInputStream(
                            credentialsJson.getBytes(StandardCharsets.UTF_8)
                    )
            );
        } else if (!credentialsPath.isBlank()) {
            credentials = GoogleCredentials.fromStream(
                    new FileInputStream(credentialsPath)
            );
        } else {
            credentials = GoogleCredentials.getApplicationDefault();
        }

        FirebaseOptions options =
                FirebaseOptions.builder()
                        .setCredentials(credentials)
                        .build();

        return FirebaseApp.getApps().stream()
                .filter(app ->
                        app.getName().equals("vehicle-inspector")
                )
                .findFirst()
                .orElseGet(() ->
                        FirebaseApp.initializeApp(
                                options,
                                "vehicle-inspector"
                        )
                );
    }
}