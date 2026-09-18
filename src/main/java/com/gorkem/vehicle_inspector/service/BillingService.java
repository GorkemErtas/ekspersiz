package com.gorkem.vehicle_inspector.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.client.RevenueCatClient;
import com.gorkem.vehicle_inspector.client.RevenueCatCustomer;
import com.gorkem.vehicle_inspector.client.RevenueCatSubscription;
import com.gorkem.vehicle_inspector.dto.response.BillingOverviewResponse;
import com.gorkem.vehicle_inspector.dto.response.BillingPlanResponse;
import com.gorkem.vehicle_inspector.dto.response.BillingStatusResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.InvalidBillingWebhookException;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.BillingSubscriptionRepository;
import com.gorkem.vehicle_inspector.repository.BillingWebhookEventRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.service.billing.BillingProduct;
import com.gorkem.vehicle_inspector.service.billing.RevenueCatWebhookVerifier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

@Service
public class BillingService {

    private final UserRepository userRepository;
    private final BillingSubscriptionRepository subscriptionRepository;
    private final BillingWebhookEventRepository webhookEventRepository;
    private final SubscriptionService subscriptionService;
    private final RevenueCatClient revenueCatClient;
    private final RevenueCatWebhookVerifier webhookVerifier;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    public BillingService(
            UserRepository userRepository,
            BillingSubscriptionRepository subscriptionRepository,
            BillingWebhookEventRepository webhookEventRepository,
            SubscriptionService subscriptionService,
            RevenueCatClient revenueCatClient,
            RevenueCatWebhookVerifier webhookVerifier,
            ObjectMapper objectMapper,
            Clock clock
    ) {
        this.userRepository = userRepository;
        this.subscriptionRepository = subscriptionRepository;
        this.webhookEventRepository = webhookEventRepository;
        this.subscriptionService = subscriptionService;
        this.revenueCatClient = revenueCatClient;
        this.webhookVerifier = webhookVerifier;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    @Transactional
    public BillingOverviewResponse getOverview(String email) {
        User user = requireUser(email);
        user.ensureBillingCustomerId();
        userRepository.save(user);
        return buildOverview(user);
    }

    @Transactional
    public BillingOverviewResponse sync(String email) {
        User user = requireUser(email);
        syncUser(user);
        return buildOverview(user);
    }

    @Transactional
    public void processRevenueCatWebhook(
            String authorization,
            String signature,
            String rawBody
    ) {
        webhookVerifier.verify(authorization, signature, rawBody);
        JsonNode event = parseEvent(rawBody);
        String eventId = requiredText(event, "id");

        if (webhookEventRepository.existsByProviderEventId(eventId)) {
            return;
        }

        String eventType = requiredText(event, "type");
        String appUserId = textOrNull(event.path("app_user_id"));

        if (!"TEST".equals(eventType)) {
            findWebhookUsers(event).forEach(this::syncUser);
        }

        webhookEventRepository.save(new BillingWebhookEvent(
                eventId,
                eventType,
                appUserId,
                LocalDateTime.now(clock)
        ));
    }

    private void syncUser(User user) {
        String billingCustomerId = user.ensureBillingCustomerId();
        RevenueCatCustomer customer = revenueCatClient.getCustomer(
                billingCustomerId
        );
        Instant now = clock.instant();

        Optional<SelectedSubscription> selected = customer.subscriptions()
                .stream()
                .map(subscription -> BillingProduct
                        .fromProductId(subscription.productId())
                        .map(product -> new SelectedSubscription(
                                product,
                                subscription
                        )))
                .flatMap(Optional::stream)
                .filter(item -> isActive(item.subscription(), now))
                .max(Comparator.comparingInt(
                        item -> item.product().getPlan().ordinal()
                ));

        BillingSubscription billingSubscription = subscriptionRepository
                .findByUserId(user.getId())
                .orElseGet(() -> new BillingSubscription(user));

        if (selected.isPresent()) {
            applyActiveSubscription(
                    user,
                    billingSubscription,
                    selected.get(),
                    customer.managementUrl()
            );
        } else {
            expireSubscription(
                    user,
                    billingSubscription,
                    customer.managementUrl()
            );
        }

        userRepository.save(user);
        subscriptionRepository.save(billingSubscription);
    }

    private void applyActiveSubscription(
            User user,
            BillingSubscription billingSubscription,
            SelectedSubscription selected,
            String managementUrl
    ) {
        RevenueCatSubscription providerSubscription =
                selected.subscription();
        LocalDateTime startedAt = toLocalDateTime(
                providerSubscription.purchasedAt()
        );
        LocalDateTime endsAt = toLocalDateTime(
                providerSubscription.accessEndsAt()
        );
        BillingSubscriptionStatus status =
                providerSubscription.billingIssue()
                        ? BillingSubscriptionStatus.BILLING_ISSUE
                        : providerSubscription.autoRenewing()
                        ? BillingSubscriptionStatus.ACTIVE
                        : BillingSubscriptionStatus.CANCELLED;

        user.setSubscriptionPlan(selected.product().getPlan());
        user.setSubscriptionStartedAt(startedAt);
        user.setSubscriptionExpiresAt(endsAt);

        billingSubscription.update(
                providerSubscription.productId(),
                status,
                providerSubscription.store(),
                providerSubscription.autoRenewing(),
                providerSubscription.sandbox(),
                startedAt,
                endsAt,
                managementUrl,
                LocalDateTime.now(clock)
        );
    }

    private void expireSubscription(
            User user,
            BillingSubscription billingSubscription,
            String managementUrl
    ) {
        user.setSubscriptionPlan(SubscriptionPlan.FREE);
        user.setSubscriptionStartedAt(null);
        user.setSubscriptionExpiresAt(null);

        billingSubscription.update(
                billingSubscription.getProductId(),
                BillingSubscriptionStatus.EXPIRED,
                billingSubscription.getStore(),
                false,
                billingSubscription.isSandbox(),
                billingSubscription.getCurrentPeriodStartedAt(),
                billingSubscription.getCurrentPeriodEndsAt(),
                managementUrl,
                LocalDateTime.now(clock)
        );
    }

    private boolean isActive(
            RevenueCatSubscription subscription,
            Instant now
    ) {
        if (subscription.refunded()) {
            return false;
        }

        Instant accessEndsAt = subscription.accessEndsAt();
        return accessEndsAt == null || accessEndsAt.isAfter(now);
    }

    private BillingOverviewResponse buildOverview(User user) {
        BillingSubscription billingSubscription = subscriptionRepository
                .findByUserId(user.getId())
                .orElse(null);
        SubscriptionPlan effectivePlan =
                subscriptionService.getEffectivePlan(user);
        BillingSubscriptionStatus effectiveStatus =
                billingSubscription == null
                        ? BillingSubscriptionStatus.NONE
                        : effectivePlan == SubscriptionPlan.FREE
                        ? BillingSubscriptionStatus.EXPIRED
                        : billingSubscription.getStatus();

        BillingStatusResponse status = new BillingStatusResponse(
                user.ensureBillingCustomerId(),
                effectivePlan,
                effectiveStatus,
                billingSubscription == null
                        ? null
                        : billingSubscription.getProductId(),
                effectivePlan != SubscriptionPlan.FREE
                        && billingSubscription != null
                        && billingSubscription.isAutoRenewing(),
                billingSubscription != null
                        && billingSubscription.isSandbox(),
                billingSubscription == null
                        ? user.getSubscriptionExpiresAt()
                        : billingSubscription.getCurrentPeriodEndsAt(),
                billingSubscription == null
                        ? null
                        : billingSubscription.getManagementUrl(),
                billingSubscription == null
                        ? null
                        : billingSubscription.getLastSyncedAt()
        );

        return new BillingOverviewResponse(status, catalog());
    }

    private List<BillingPlanResponse> catalog() {
        List<BillingPlanResponse> plans = new ArrayList<>();
        plans.add(new BillingPlanResponse(
                SubscriptionPlan.FREE,
                "Ücretsiz",
                "Temel bireysel kullanım",
                null,
                null,
                BigDecimal.ZERO,
                "TRY",
                false,
                List.of("1 aktif araç", "Ayda 1 AI hasar analizi")
        ));

        for (BillingProduct product : BillingProduct.values()) {
            plans.add(new BillingPlanResponse(
                    product.getPlan(),
                    product.getTitle(),
                    product.getDescription(),
                    product.getProductId(),
                    product.getPackageIdentifier(),
                    product.getFallbackMonthlyPrice(),
                    "TRY",
                    product.isHighlighted(),
                    product.getFeatures()
            ));
        }

        return List.copyOf(plans);
    }

    private List<User> findWebhookUsers(JsonNode event) {
        Set<String> candidates = new LinkedHashSet<>();
        addCandidate(candidates, event.path("app_user_id"));
        addCandidate(candidates, event.path("original_app_user_id"));
        addCandidates(candidates, event.path("aliases"));
        addCandidates(candidates, event.path("transferred_from"));
        addCandidates(candidates, event.path("transferred_to"));

        return candidates.stream()
                .map(userRepository::findByBillingCustomerId)
                .flatMap(Optional::stream)
                .collect(
                        java.util.stream.Collectors.collectingAndThen(
                                java.util.stream.Collectors.toMap(
                                        User::getId,
                                        user -> user,
                                        (first, ignored) -> first,
                                        java.util.LinkedHashMap::new
                                ),
                                users -> List.copyOf(users.values())
                        )
                );
    }

    private void addCandidates(Set<String> candidates, JsonNode values) {
        if (!values.isArray()) {
            return;
        }

        values.forEach(value -> addCandidate(candidates, value));
    }

    private void addCandidate(Set<String> candidates, JsonNode value) {
        String candidate = textOrNull(value);

        if (candidate != null) {
            candidates.add(candidate);
        }
    }

    private JsonNode parseEvent(String rawBody) {
        try {
            JsonNode event = objectMapper.readTree(rawBody).path("event");

            if (!event.isObject()) {
                throw new InvalidBillingWebhookException(
                        "Ödeme webhook gövdesi geçersiz."
                );
            }

            return event;
        } catch (JsonProcessingException exception) {
            throw new InvalidBillingWebhookException(
                    "Ödeme webhook gövdesi geçersiz."
            );
        }
    }

    private String requiredText(JsonNode node, String fieldName) {
        String value = textOrNull(node.path(fieldName));

        if (value == null) {
            throw new InvalidBillingWebhookException(
                    "Ödeme webhook alanı eksik: " + fieldName
            );
        }

        return value;
    }

    private String textOrNull(JsonNode node) {
        if (node == null || node.isMissingNode() || node.isNull()) {
            return null;
        }

        String value = node.asText();
        return value.isBlank() ? null : value;
    }

    private LocalDateTime toLocalDateTime(Instant instant) {
        return instant == null
                ? null
                : LocalDateTime.ofInstant(instant, clock.getZone());
    }

    private User requireUser(String email) {
        return userRepository.findByEmail(email.trim().toLowerCase())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Kullanıcı bulunamadı."
                ));
    }

    private record SelectedSubscription(
            BillingProduct product,
            RevenueCatSubscription subscription
    ) {
    }
}
