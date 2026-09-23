package com.gorkem.vehicle_inspector.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;

import java.io.FileInputStream;
import java.io.IOException;

@Configuration
@ConditionalOnProperty(
        name = "application.notifications.fcm.enabled",
        havingValue = "true"
)
public class FirebaseConfig {

    private final String credentialsPath;

    public FirebaseConfig(
            @Value("${application.notifications.fcm.credentials-path:}")
            String credentialsPath
    ) {
        this.credentialsPath = credentialsPath;
    }

    @Bean
    public FirebaseApp firebaseApp() throws IOException {
        GoogleCredentials credentials =
                credentialsPath.isBlank()
                        ? GoogleCredentials.getApplicationDefault()
                        : GoogleCredentials.fromStream(
                        new FileInputStream(credentialsPath)
                );

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