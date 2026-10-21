package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.exception.RateLimitExceededException;
import com.gorkem.vehicle_inspector.security.RequestRateLimiter;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.context.annotation.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.transaction.support.TransactionTemplate;

import javax.sql.DataSource;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.concurrent.*;

import static com.gorkem.vehicle_inspector.security.RequestRateLimiter.Action.*;
import static org.junit.jupiter.api.Assertions.*;

/** Requires an explicitly named disposable database, never application configuration. */
@EnabledIfSystemProperty(named = "security.test.jdbc-url",
        matches = "jdbc:postgresql://(127\\.0\\.0\\.1|localhost):[0-9]+/security_audit_test")
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class RequestRateLimiterPersistenceTest {
    private AnnotationConfigApplicationContext app;
    private JdbcTemplate jdbc;
    private RequestRateLimiter limiter;

    @BeforeAll void setupSchema() throws Exception {
        var admin = new JdbcTemplate(new DriverManagerDataSource(System.getProperty("security.test.jdbc-url"),
                System.getProperty("security.test.username", "security_test"), ""));
        admin.execute("CREATE SCHEMA auth_security_test");
        app = new AnnotationConfigApplicationContext(Config.class);
        jdbc = app.getBean(JdbcTemplate.class);
        // Verify the real additive migration against existing credential data.
        jdbc.execute("CREATE TABLE users (id bigint PRIMARY KEY, password text, subscription_plan text)");
        jdbc.update("INSERT INTO users VALUES (1, 'unchanged-hash', 'PRO')");
        jdbc.execute(Files.readString(Path.of("src/main/resources/db/migration/V15__authentication_security.sql")));
        assertEquals(0, jdbc.queryForObject("SELECT auth_version FROM users WHERE id=1", Long.class));
        assertEquals("unchanged-hash", jdbc.queryForObject("SELECT password FROM users WHERE id=1", String.class));
        assertEquals("PRO", jdbc.queryForObject("SELECT subscription_plan FROM users WHERE id=1", String.class));
        limiter = app.getBean(RequestRateLimiter.class);
    }

    @AfterAll void close() {
        if (app != null) {
            jdbc.execute("DROP SCHEMA auth_security_test CASCADE");
            app.close();
        }
    }
    @BeforeEach void clean() { jdbc.update("DELETE FROM authentication_rate_limits"); }

    @Test void concurrentAttemptsCannotExceedFiveAndRawIdentityIsNotStored() throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(10);
        try {
            var work = new ArrayList<Callable<Boolean>>();
            for (int i=0; i<20; i++) work.add(() -> {
                try { limiter.check(RESET_CHECK, " Owner@Example.com "); return true; }
                catch (RateLimitExceededException limit) { return false; }
            });
            long accepted = 0;
            for (var result : pool.invokeAll(work)) if (result.get(10, TimeUnit.SECONDS)) accepted++;
            assertEquals(5, accepted);
            assertEquals(5, jdbc.queryForObject("SELECT attempts FROM authentication_rate_limits", Integer.class));
            assertFalse(jdbc.queryForObject("SELECT bucket_key FROM authentication_rate_limits", String.class).contains("owner"));
        } finally { pool.shutdownNow(); }
    }

    @Test void failureRollbackAndNewServiceInstanceDoNotResetAttempts() {
        TransactionTemplate outer = new TransactionTemplate(app.getBean(PlatformTransactionManager.class));
        for (int i=0; i<5; i++) assertThrows(IllegalArgumentException.class, () -> outer.execute(status -> {
            limiter.check(VERIFICATION_CHECK, "owner@example.com");
            throw new IllegalArgumentException("wrong code");
        }));
        var exception = assertThrows(RateLimitExceededException.class,
                () -> limiter.check(VERIFICATION_CHECK, "OWNER@EXAMPLE.COM"));
        assertTrue(exception.getRetryAfterSeconds() > 0 && exception.getRetryAfterSeconds() <= 900);
        assertThrows(RateLimitExceededException.class, () ->
                outer.executeWithoutResult(status -> new RequestRateLimiter(jdbc)
                        .check(VERIFICATION_CHECK, "owner@example.com")));
    }

    @Test void expiredWindowResetsAndDifferentAccountOrActionIsIndependent() {
        for (int i=0; i<3; i++) limiter.check(VERIFICATION_SEND, "owner@example.com");
        assertThrows(RateLimitExceededException.class, () -> limiter.check(VERIFICATION_SEND, "owner@example.com"));
        assertDoesNotThrow(() -> limiter.check(VERIFICATION_SEND, "other@example.com"));
        assertDoesNotThrow(() -> limiter.check(RESET_SEND, "owner@example.com"));
        jdbc.update("UPDATE authentication_rate_limits SET expires_at=CURRENT_TIMESTAMP-INTERVAL '1 second'");
        assertDoesNotThrow(() -> limiter.check(VERIFICATION_SEND, "owner@example.com"));
    }

    @Configuration @EnableTransactionManagement @Import(RequestRateLimiter.class)
    static class Config {
        @Bean DataSource dataSource() {
            return new DriverManagerDataSource(System.getProperty("security.test.jdbc-url") + "?currentSchema=auth_security_test",
                    System.getProperty("security.test.username", "security_test"), "");
        }
        @Bean JdbcTemplate jdbcTemplate(DataSource source) { return new JdbcTemplate(source); }
        @Bean PlatformTransactionManager transactionManager(DataSource source) { return new DataSourceTransactionManager(source); }
    }
}
