package com.gorkem.vehicle_inspector;

import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * PostgreSQL row-lock concurrency contract for the business assistant quota.
 * Run explicitly with: ./mvnw -Dtest=AiAssistantBusinessConcurrencyIT test
 * This exercises the SQL locking strategy, not the full HTTP/service flow.
 */
@Testcontainers(disabledWithoutDocker = true)
class AiAssistantBusinessConcurrencyIT {
    @Container
    static final PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>("postgres:16-alpine");

    @Test
    void simultaneousRequestsCannotReserveMoreThanTenSharedQuestions() throws Exception {
        try (Connection setup = connection(); Statement sql = setup.createStatement()) {
            sql.execute("CREATE TABLE business_accounts (id BIGINT PRIMARY KEY)");
            sql.execute("INSERT INTO business_accounts (id) VALUES (1)");
            sql.execute("CREATE TABLE assistant_test_usage (business_id BIGINT PRIMARY KEY, used INT NOT NULL)");
            sql.execute("INSERT INTO assistant_test_usage VALUES (1, 0)");
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
                                    "SELECT id FROM business_accounts WHERE id = 1 FOR UPDATE")) {
                                lock.executeQuery().close();
                            }
                            int used;
                            try (Statement statement = connection.createStatement();
                                 ResultSet rs = statement.executeQuery(
                                         "SELECT used FROM assistant_test_usage WHERE business_id = 1")) {
                                assertTrue(rs.next());
                                used = rs.getInt(1);
                            }
                            if (used >= 10) {
                                connection.commit();
                                return false;
                            }
                            try (Statement statement = connection.createStatement()) {
                                statement.executeUpdate(
                                        "UPDATE assistant_test_usage SET used = used + 1 WHERE business_id = 1");
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
            for (Future<Boolean> result : results)
                if (result.get(60, TimeUnit.SECONDS)) accepted++;
            assertEquals(10, accepted);
            try (Connection check = connection(); Statement sql = check.createStatement();
                 ResultSet rs = sql.executeQuery(
                         "SELECT used FROM assistant_test_usage WHERE business_id = 1")) {
                assertTrue(rs.next());
                assertEquals(10, rs.getInt(1));
            }
        } finally {
            start.countDown();
            executor.shutdownNow();
        }
    }

    private Connection connection() throws Exception {
        return DriverManager.getConnection(
                postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
    }
}
