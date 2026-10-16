package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.service.ReminderNotificationScheduler;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

/**
 * External trigger for the existing reminder evaluation.
 * Requires a dedicated machine-to-machine token; no user session is accepted.
 */
@RestController
@RequestMapping("/api/v1/internal/reminders")
public class InternalReminderJobController {
    private final ReminderNotificationScheduler scheduler;
    private final String expectedToken;

    public InternalReminderJobController(
            ReminderNotificationScheduler scheduler,
            @Value("${application.notifications.job-token:}") String expectedToken) {
        this.scheduler = scheduler;
        this.expectedToken = expectedToken;
    }

    @PostMapping("/execute")
    public ResponseEntity<Map<String, String>> execute(
            @RequestHeader(value = "X-Reminder-Job-Token", required = false)
            String suppliedToken) {
        // Fail closed if the server was deployed without its secret.
        if (expectedToken == null || expectedToken.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE);
        }
        if (suppliedToken == null || !MessageDigest.isEqual(
                expectedToken.getBytes(StandardCharsets.UTF_8),
                suppliedToken.getBytes(StandardCharsets.UTF_8))) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        }

        scheduler.evaluateDueReminders();
        return ResponseEntity.ok(Map.of("status", "processed"));
    }
}
