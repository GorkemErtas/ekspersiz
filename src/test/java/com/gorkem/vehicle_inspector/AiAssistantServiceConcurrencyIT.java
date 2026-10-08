package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.ImportAutoConfiguration;
import org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Clock;
import java.time.ZoneId;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Real Spring transaction/JPA integration test for reserveQuestion().
 * Explicit run: ./mvnw -Dtest=AiAssistantServiceConcurrencyIT test
 * Uses pgvector because the application's Flyway migrations require vector.
 */
@DataJpaTest
@Import({AiAssistantEntitlementService.class, AiAssistantServiceConcurrencyIT.ClockConfig.class})
@ImportAutoConfiguration(FlywayAutoConfiguration.class)
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@Testcontainers(disabledWithoutDocker = true)
class AiAssistantServiceConcurrencyIT {
    @Container
    static final PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>("pgvector/pgvector:pg16");

    @DynamicPropertySource
    static void database(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.datasource.hikari.maximum-pool-size", () -> "24");
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "validate");
    }

    @TestConfiguration
    static class ClockConfig {
        @Bean Clock clock() { return Clock.system(ZoneId.of("Europe/Istanbul")); }
    }

    @Autowired AiAssistantEntitlementService service;
    @Autowired UserRepository users;
    @Autowired BusinessAccountRepository businesses;
    @Autowired AiAssistantQuotaReservationRepository reservations;
    @MockitoBean BusinessContextService businessContext;
    @MockitoBean SubscriptionService subscriptions;

    @Test
    void realServiceAllowsOnlyTenReservationsAcrossTwentyWorkers() throws Exception {
        BusinessAccount company = businesses.saveAndFlush(new BusinessAccount("Concurrent Ltd"));
        Map<String, User> workers = new HashMap<>();
        for (int i = 0; i < 20; i++) {
            String email = "concurrent-" + i + "@example.com";
            workers.put(email, users.saveAndFlush(new User("Worker " + i, email, "password")));
        }
        when(businessContext.requireUser(any(String.class)))
                .thenAnswer(call -> workers.get(call.getArgument(0, String.class)));
        when(businessContext.isBusinessMember(any(User.class))).thenReturn(true);
        when(businessContext.requireBusinessAccount(any(User.class))).thenReturn(company);
        when(subscriptions.getEffectivePlan(any(User.class))).thenReturn(SubscriptionPlan.BUSINESS);

        ExecutorService pool = Executors.newFixedThreadPool(20);
        CountDownLatch ready = new CountDownLatch(20);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<Boolean>> futures = new ArrayList<>();
        try {
            for (String email : workers.keySet()) {
                futures.add(pool.submit(() -> {
                    ready.countDown();
                    if (!start.await(20, TimeUnit.SECONDS))
                        throw new IllegalStateException("Concurrent workers did not start");
                    try {
                        service.reserveQuestion(email);
                        return true;
                    } catch (IllegalStateException quotaReached) {
                        if (!quotaReached.getMessage().contains("kota")) throw quotaReached;
                        return false;
                    }
                }));
            }
            assertTrue(ready.await(20, TimeUnit.SECONDS));
            start.countDown();
            int accepted = 0;
            for (Future<Boolean> future : futures)
                if (future.get(90, TimeUnit.SECONDS)) accepted++;
            assertEquals(10, accepted, "Business daily quota must be shared transactionally");
            long active = reservations.countBusinessActive(
                    company.getId(), java.time.LocalDate.now(ZoneId.of("Europe/Istanbul")),
                    java.time.LocalDateTime.now(ZoneId.of("Europe/Istanbul")));
            assertEquals(10, active);
        } finally {
            start.countDown();
            pool.shutdownNow();
        }
    }
}
