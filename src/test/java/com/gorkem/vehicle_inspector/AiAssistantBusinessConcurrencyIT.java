package com.gorkem.vehicle_inspector;

import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.*;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * PostgreSQL concurrency contract for the same shared quota SQL used by
 * AiAssistantEntitlementService: completed usage + active reservations.
 * Run explicitly: ./mvnw -Dtest=AiAssistantBusinessConcurrencyIT test
 * This is a SQL contract test, not a full Spring service integration test.
 */
@Testcontainers(disabledWithoutDocker = true)
class AiAssistantBusinessConcurrencyIT {
    @Container
    static final PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>("postgres:16-alpine");

    @Test
    void parallelReservationsRespectSharedLimitIncludingPendingQuestions() throws Exception {
        LocalDate day = LocalDate.of(2026, 10, 8);
        LocalDateTime now = day.atTime(12, 0);
        try (Connection setup = connection(); Statement sql = setup.createStatement()) {
            sql.execute("CREATE TABLE business_accounts (id BIGINT PRIMARY KEY)");
            sql.execute("INSERT INTO business_accounts (id) VALUES (1)");
            sql.execute("""
                    CREATE TABLE ai_assistant_business_daily_usage (
                        business_account_id BIGINT NOT NULL, usage_date DATE NOT NULL,
                        successful_questions INT NOT NULL,
                        PRIMARY KEY (business_account_id, usage_date))
                    """);
            sql.execute("""
                    CREATE TABLE ai_assistant_quota_reservations (
                        id UUID PRIMARY KEY, business_account_id BIGINT NOT NULL,
                        usage_date DATE NOT NULL, status VARCHAR(20) NOT NULL,
                        expires_at TIMESTAMP NOT NULL)
                    """);
            sql.execute("INSERT INTO ai_assistant_business_daily_usage VALUES (1, DATE '2026-10-08', 3)");
            // Expired reservations must not occupy today's remaining slots.
            sql.execute("""
                    INSERT INTO ai_assistant_quota_reservations VALUES
                    ('00000000-0000-0000-0000-000000000001', 1, DATE '2026-10-08',
                     'RESERVED', TIMESTAMP '2026-10-08 11:59:00')
                    """);
        }

        int attempts = 24;
        ExecutorService executor = Executors.newFixedThreadPool(attempts);
        CountDownLatch ready = new CountDownLatch(attempts);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<Boolean>> results = new ArrayList<>();
        try {
            for (int i = 0; i < attempts; i++) {
                results.add(executor.submit(() -> {
                    ready.countDown();
                    if (!start.await(15, TimeUnit.SECONDS))
                        throw new IllegalStateException("Workers did not start together");
                    try (Connection connection = connection()) {
                        connection.setAutoCommit(false);
                        try {
                            try (PreparedStatement lock = connection.prepareStatement(
                                    "SELECT id FROM business_accounts WHERE id = ? FOR UPDATE")) {
                                lock.setLong(1, 1L);
                                try (ResultSet rs = lock.executeQuery()) {
                                    assertTrue(rs.next());
                                }
                            }
                            int used;
                            try (PreparedStatement statement = connection.prepareStatement(
                                    "SELECT COALESCE(SUM(successful_questions), 0) " +
                                    "FROM ai_assistant_business_daily_usage " +
                                    "WHERE business_account_id = ? AND usage_date = ?")) {
                                statement.setLong(1, 1L);
                                statement.setDate(2, java.sql.Date.valueOf(day));
                                try (ResultSet rs = statement.executeQuery()) {
                                    assertTrue(rs.next());
                                    used = rs.getInt(1);
                                }
                            }
                            int reserved;
                            try (PreparedStatement statement = connection.prepareStatement(
                                    "SELECT COUNT(*) FROM ai_assistant_quota_reservations " +
                                    "WHERE business_account_id = ? AND usage_date = ? " +
                                    "AND status = 'RESERVED' AND expires_at > ?")) {
                                statement.setLong(1, 1L);
                                statement.setDate(2, java.sql.Date.valueOf(day));
                                statement.setTimestamp(3, Timestamp.valueOf(now));
                                try (ResultSet rs = statement.executeQuery()) {
                                    assertTrue(rs.next());
                                    reserved = rs.getInt(1);
                                }
                            }
                            if (used + reserved >= 10) {
                                connection.commit();
                                return false;
                            }
                            try (PreparedStatement statement = connection.prepareStatement(
                                    "INSERT INTO ai_assistant_quota_reservations " +
                                    "(id, business_account_id, usage_date, status, expires_at) " +
                                    "VALUES (?, ?, ?, 'RESERVED', ?)")) {
                                statement.setObject(1, UUID.randomUUID());
                                statement.setLong(2, 1L);
                                statement.setDate(3, java.sql.Date.valueOf(day));
                                statement.setTimestamp(4, Timestamp.valueOf(now.plusMinutes(5)));
                                statement.executeUpdate();
                            }
                            connection.commit();
                            return true;
                        } catch (Exception e) {
                            connection.rollback();
                            throw e;
                        }
                    }
                }));
            }
            assertTrue(ready.await(15, TimeUnit.SECONDS));
            start.countDown();
            int accepted = 0;
            for (Future<Boolean> result : results) {
                if (result.get(60, TimeUnit.SECONDS)) accepted++;
            }
            assertEquals(7, accepted, "Three completed questions leave seven slots");
            try (Connection check = connection();
                 PreparedStatement statement = check.prepareStatement(
                         "SELECT COUNT(*) FROM ai_assistant_quota_reservations " +
                         "WHERE status = 'RESERVED' AND expires_at > ?")) {
                statement.setTimestamp(1, Timestamp.valueOf(now));
                try (ResultSet rs = statement.executeQuery()) {
                    assertTrue(rs.next());
                    assertEquals(7, rs.getInt(1));
                }
            }
        } finally {
            start.countDown();
            executor.shutdownNow();
        }
    }

    private Connection connection() throws SQLException {
        return DriverManager.getConnection(
                postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
    }
}
