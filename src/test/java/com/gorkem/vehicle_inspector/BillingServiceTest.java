package com.gorkem.vehicle_inspector;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.client.RevenueCatClient;
import com.gorkem.vehicle_inspector.client.RevenueCatCustomer;
import com.gorkem.vehicle_inspector.client.RevenueCatSubscription;
import com.gorkem.vehicle_inspector.entity.BillingSubscription;
import com.gorkem.vehicle_inspector.entity.BillingSubscriptionStatus;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.BillingSubscriptionRepository;
import com.gorkem.vehicle_inspector.repository.BillingWebhookEventRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.BillingService;
import com.gorkem.vehicle_inspector.service.SubscriptionService;
import com.gorkem.vehicle_inspector.service.billing.RevenueCatWebhookVerifier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BillingServiceTest {

    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-09-16T09:00:00Z"),
            ZoneOffset.UTC
    );

    @Mock private UserRepository users;
    @Mock private BillingSubscriptionRepository subscriptions;
    @Mock private BillingWebhookEventRepository webhookEvents;
    @Mock private SubscriptionService subscriptionService;
    @Mock private RevenueCatClient revenueCatClient;
    @Mock private RevenueCatWebhookVerifier webhookVerifier;

    private BillingService service;
    private User user;

    @BeforeEach
    void setUp() {
        user = new User("Test User", "test@example.com", "password");
        ReflectionTestUtils.setField(user, "id", 7L);

        lenient().when(users.findByEmail("test@example.com"))
                .thenReturn(Optional.of(user));
        lenient().when(subscriptions.findByUserId(7L))
                .thenReturn(Optional.empty());
        lenient().when(subscriptionService.getEffectivePlan(user))
                .thenAnswer(invocation -> user.getSubscriptionPlan());

        service = new BillingService(
                users,
                subscriptions,
                webhookEvents,
                subscriptionService,
                revenueCatClient,
                webhookVerifier,
                new ObjectMapper(),
                CLOCK
        );
    }

    @Test
    void activeStoreSubscriptionShouldUpgradeUser() {
        when(revenueCatClient.getCustomer(user.getBillingCustomerId()))
                .thenReturn(customer(subscription(
                        "eksper_pro_monthly",
                        true,
                        false,
                        false,
                        Instant.parse("2026-10-16T09:00:00Z")
                )));

        service.sync(" TEST@EXAMPLE.COM ");

        assertEquals(SubscriptionPlan.PRO, user.getSubscriptionPlan());
        assertEquals(
                java.time.LocalDateTime.parse("2026-10-16T09:00:00"),
                user.getSubscriptionExpiresAt()
        );

        ArgumentCaptor<BillingSubscription> captor =
                ArgumentCaptor.forClass(BillingSubscription.class);
        verify(subscriptions).save(captor.capture());
        assertEquals(BillingSubscriptionStatus.ACTIVE, captor.getValue().getStatus());
        assertTrue(captor.getValue().isAutoRenewing());
    }

    @Test
    void cancelledSubscriptionShouldKeepAccessUntilPeriodEnd() {
        when(revenueCatClient.getCustomer(user.getBillingCustomerId()))
                .thenReturn(customer(subscription(
                        "eksper_plus_monthly",
                        false,
                        false,
                        false,
                        Instant.parse("2026-09-20T09:00:00Z")
                )));

        service.sync("test@example.com");

        assertEquals(SubscriptionPlan.PLUS, user.getSubscriptionPlan());
        ArgumentCaptor<BillingSubscription> captor =
                ArgumentCaptor.forClass(BillingSubscription.class);
        verify(subscriptions).save(captor.capture());
        assertEquals(BillingSubscriptionStatus.CANCELLED, captor.getValue().getStatus());
    }

    @Test
    void expiredOrRefundedSubscriptionShouldReturnUserToFree() {
        user.setSubscriptionPlan(SubscriptionPlan.BUSINESS);
        when(revenueCatClient.getCustomer(user.getBillingCustomerId()))
                .thenReturn(customer(subscription(
                        "eksper_business_monthly",
                        false,
                        false,
                        true,
                        Instant.parse("2026-10-16T09:00:00Z")
                )));

        service.sync("test@example.com");

        assertEquals(SubscriptionPlan.FREE, user.getSubscriptionPlan());
        assertNull(user.getSubscriptionStartedAt());
        assertNull(user.getSubscriptionExpiresAt());
    }

    @Test
    void duplicateWebhookShouldBeAcknowledgedWithoutSecondSync() {
        String body = """
                {"event":{"id":"event-1","type":"RENEWAL","app_user_id":"%s"}}
                """.formatted(user.getBillingCustomerId());
        when(webhookEvents.existsByProviderEventId("event-1"))
                .thenReturn(false, true);
        when(users.findByBillingCustomerId(user.getBillingCustomerId()))
                .thenReturn(Optional.of(user));
        when(revenueCatClient.getCustomer(user.getBillingCustomerId()))
                .thenReturn(customer(subscription(
                        "eksper_plus_monthly",
                        true,
                        false,
                        false,
                        Instant.parse("2026-10-16T09:00:00Z")
                )));

        service.processRevenueCatWebhook("Bearer secret", "signature", body);
        service.processRevenueCatWebhook("Bearer secret", "signature", body);

        verify(webhookVerifier, times(2))
                .verify("Bearer secret", "signature", body);
        verify(revenueCatClient, times(1))
                .getCustomer(user.getBillingCustomerId());
        verify(webhookEvents, times(1)).save(any());
    }

    @Test
    void transferWebhookShouldRefreshBothPreviousAndNewCustomer() {
        user.setSubscriptionPlan(SubscriptionPlan.PRO);
        User destination = new User(
                "Destination User",
                "destination@example.com",
                "password"
        );
        ReflectionTestUtils.setField(destination, "id", 8L);
        String body = """
                {"event":{
                  "id":"transfer-1",
                  "type":"TRANSFER",
                  "app_user_id":"%s",
                  "transferred_from":["%s"],
                  "transferred_to":["%s"]
                }}
                """.formatted(
                destination.getBillingCustomerId(),
                user.getBillingCustomerId(),
                destination.getBillingCustomerId()
        );

        when(webhookEvents.existsByProviderEventId("transfer-1"))
                .thenReturn(false);
        when(users.findByBillingCustomerId(user.getBillingCustomerId()))
                .thenReturn(Optional.of(user));
        when(users.findByBillingCustomerId(destination.getBillingCustomerId()))
                .thenReturn(Optional.of(destination));
        when(subscriptions.findByUserId(8L)).thenReturn(Optional.empty());
        when(revenueCatClient.getCustomer(user.getBillingCustomerId()))
                .thenReturn(new RevenueCatCustomer(List.of(), null));
        when(revenueCatClient.getCustomer(destination.getBillingCustomerId()))
                .thenReturn(customer(subscription(
                        "eksper_plus_monthly",
                        true,
                        false,
                        false,
                        Instant.parse("2026-10-16T09:00:00Z")
                )));

        service.processRevenueCatWebhook("Bearer secret", "signature", body);

        assertEquals(SubscriptionPlan.FREE, user.getSubscriptionPlan());
        assertEquals(SubscriptionPlan.PLUS, destination.getSubscriptionPlan());
        verify(revenueCatClient).getCustomer(user.getBillingCustomerId());
        verify(revenueCatClient).getCustomer(destination.getBillingCustomerId());
    }

    private RevenueCatCustomer customer(RevenueCatSubscription subscription) {
        return new RevenueCatCustomer(
                List.of(subscription),
                "https://apps.apple.com/account/subscriptions"
        );
    }

    private RevenueCatSubscription subscription(
            String productId,
            boolean autoRenewing,
            boolean billingIssue,
            boolean refunded,
            Instant expiresAt
    ) {
        return new RevenueCatSubscription(
                productId,
                Instant.parse("2026-09-16T09:00:00Z"),
                expiresAt,
                null,
                autoRenewing,
                billingIssue,
                refunded,
                true,
                "app_store"
        );
    }
}
