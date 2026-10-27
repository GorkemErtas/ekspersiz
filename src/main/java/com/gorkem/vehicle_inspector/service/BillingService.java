package com.gorkem.vehicle_inspector.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.client.RevenueCatClient;
import com.gorkem.vehicle_inspector.client.RevenueCatCustomer;
import com.gorkem.vehicle_inspector.client.RevenueCatSubscription;
import com.gorkem.vehicle_inspector.client.RevenueCatPurchase;
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
import com.gorkem.vehicle_inspector.service.billing.BillingSandboxPolicy;
import com.gorkem.vehicle_inspector.service.billing.RevenueCatWebhookVerifier;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
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
    @Autowired
    private CreditWalletService creditWallets;

    @Autowired
    private BillingSandboxPolicy sandboxPolicy = new BillingSandboxPolicy("");

    @Autowired
    private com.gorkem.vehicle_inspector.service.billing.BusinessBillingPolicy businessBilling;

    @Autowired
    private org.springframework.jdbc.core.JdbcTemplate billingJdbc;

    private final UserRepository userRepository;
    private final BillingSubscriptionRepository subscriptionRepository;
    private final BillingWebhookEventRepository webhookEventRepository;
    private final SubscriptionService subscriptionService;
    private final RevenueCatClient revenueCatClient;
    private final RevenueCatWebhookVerifier webhookVerifier;
    private final ObjectMapper objectMapper;
    private final Clock clock;
    private final AnalysisCreditService analysisCreditService;

    @Autowired
    public BillingService(
            UserRepository userRepository,
            BillingSubscriptionRepository subscriptionRepository,
            BillingWebhookEventRepository webhookEventRepository,
            SubscriptionService subscriptionService,
            RevenueCatClient revenueCatClient,
            RevenueCatWebhookVerifier webhookVerifier,
            ObjectMapper objectMapper,
            Clock clock,
            AnalysisCreditService analysisCreditService
    ) {
        this.userRepository = userRepository;
        this.subscriptionRepository = subscriptionRepository;
        this.webhookEventRepository = webhookEventRepository;
        this.subscriptionService = subscriptionService;
        this.revenueCatClient = revenueCatClient;
        this.webhookVerifier = webhookVerifier;
        this.objectMapper = objectMapper;
        this.clock = clock;
        this.analysisCreditService = analysisCreditService;
    }

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
        this(userRepository, subscriptionRepository, webhookEventRepository,
                subscriptionService, revenueCatClient, webhookVerifier,
                objectMapper, clock, null);
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
        User user = userRepository.findByEmailForUpdate(email.trim().toLowerCase())
                .orElseThrow(() -> new ResourceNotFoundException("Kullanıcı bulunamadı."));
        String verification = syncUser(user);
        return buildOverview(user, verification);
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

        String eventType = requiredText(event, "type");
        String appUserId = textOrNull(event.path("app_user_id"));
        String environment = textOrNull(event.path("environment"));
        if (!Set.of("PRODUCTION", "SANDBOX").contains(environment == null ? "" : environment)) {
            if (Set.of("TEST", "TRANSFER").contains(eventType)) environment = "CONTROL";
            else throw new InvalidBillingWebhookException("Ödeme ortamı eksik veya geçersiz.");
        }
        boolean sandbox = "SANDBOX".equals(environment);
        if (billingJdbc != null) {
            billingJdbc.execute("SET LOCAL lock_timeout='3s'");
            billingJdbc.queryForObject("SELECT pg_advisory_xact_lock(hashtextextended(?, 0))", Object.class,
                    "billing-event:" + environment + ":" + eventId);
        }
        if (webhookEventRepository.existsByProviderEventIdAndEnvironmentIn(eventId, List.of(environment, "LEGACY"))) return;

        String creditProduct = textOrNull(event.path("product_id"));
        boolean consumable = com.gorkem.vehicle_inspector.service.billing.CreditCatalog.find(creditProduct) != null
                || (creditProduct != null && Set.of("analysis_1", "analysis_3", "analysis_10").contains(creditProduct));
        if (creditWallets != null && consumable && Set.of("NON_RENEWING_PURCHASE", "CANCELLATION").contains(eventType)) {
            // Only the exact authenticated provider customer may receive a consumable; never walk aliases.
            User buyer=userRepository.findByBillingCustomerIdForUpdate(appUserId).orElse(null);
            boolean refund = "CANCELLATION".equals(eventType);
            // Refunds must still reach sandbox tombstones after authorization removal/deletion.
            // They can never address production or unclassified historical rows.
            if (sandbox && !refund && !sandboxPolicy.allowsPurchase(buyer, creditProduct)) return;
            if (buyer==null && !"CANCELLATION".equals(eventType))
                throw new InvalidBillingWebhookException("Satın alma müşterisi bulunamadı.");
            long purchasedMillis=event.path("purchased_at_ms").asLong(0);
            creditWallets.purchase(buyer,creditProduct,requiredText(event,"transaction_id"),
                    purchasedMillis>0?toLocalDateTime(Instant.ofEpochMilli(purchasedMillis)):null,
                    refund, sandbox);
            webhookEventRepository.save(new BillingWebhookEvent(eventId,eventType,appUserId,LocalDateTime.now(clock),environment));
            return;
        }

        if (sandbox && !"TRANSFER".equals(eventType)) {
            // Never authorize by aliases or subscriber attributes. A webhook is a signal;
            // the canonical customer's current receipt is reverified via the secret API.
            User buyer = userRepository.findByBillingCustomerIdForUpdate(appUserId).orElse(null);
            if (buyer == null) return;
            if (!sandboxPolicy.allows(buyer)
                    && (businessBilling == null || !businessBilling.sandboxSubscription(buyer))) return;
            syncUser(buyer); // Includes expiry/refund/revocation for previously authorized accounts.
            webhookEventRepository.save(new BillingWebhookEvent(eventId, eventType, appUserId, LocalDateTime.now(clock), environment));
            return;
        }

        if (!"TEST".equals(eventType)) {
            List<User> users = findWebhookUsers(event);
            if ("NON_RENEWING_PURCHASE".equals(eventType)) {
                String productId = requiredText(event, "product_id");
                String transactionId = requiredText(event, "transaction_id");
                if (analysisCreditService != null) {
                    users.forEach(user -> analysisCreditService.grantPurchase(
                            user, productId, transactionId));
                }
            } else if ("CANCELLATION".equals(eventType)
                    && textOrNull(event.path("product_id")) != null
                    && textOrNull(event.path("product_id")).startsWith("analysis_")) {
                String productId = requiredText(event, "product_id");
                String transactionId = requiredText(event, "transaction_id");
                if (analysisCreditService != null) {
                    users.forEach(user -> analysisCreditService.revokePurchase(
                            user, productId, transactionId));
                }
            } else {
                users.forEach(this::syncUser);
            }
        }

        webhookEventRepository.save(new BillingWebhookEvent(
                eventId,
                eventType,
                appUserId,
                LocalDateTime.now(clock),
                environment
        ));
    }

    private String syncUser(User user) {
        String billingCustomerId = user.ensureBillingCustomerId();
        RevenueCatCustomer customer = revenueCatClient.getCustomer(
                billingCustomerId
        );
        Instant now = clock.instant();

        boolean sandboxAllowed = businessBilling != null && businessBilling.allowsSandboxSubscription(user)
                && billingCustomerId.equals(customer.originalAppUserId());
        Optional<SelectedSubscription> selected = customer.subscriptions()
                .stream()
                .filter(subscription -> !subscription.sandbox() || (sandboxAllowed
                        && BillingProduct.fromProductId(subscription.productId()).orElse(null) == BillingProduct.BUSINESS))
                .map(subscription -> BillingProduct
                        .fromProductId(subscription.productId())
                        .map(product -> new SelectedSubscription(
                                product,
                                subscription
                        )))
                .flatMap(Optional::stream)
                .filter(item -> isActive(item.subscription(), now))
                // Any active real subscription wins over a test receipt, including legacy personal plans.
                .max(Comparator.<SelectedSubscription, Boolean>comparing(item -> !item.subscription().sandbox())
                        .thenComparingInt(item -> item.product().getPlan().ordinal())
                        .thenComparing(item -> item.subscription().accessEndsAt()));

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
        // Authorization and wallets use JDBC in this same transaction; expose the verified source before reading it.
        subscriptionRepository.flush();
        if (creditWallets != null) {
            for (RevenueCatPurchase purchase : customer.purchases()) {
                if (purchase.sandbox() && !purchase.refunded()
                        && !sandboxPolicy.allowsPurchase(user, purchase.productId())) continue;
                creditWallets.purchase(user,purchase.productId(),purchase.transactionId(),
                        toLocalDateTime(purchase.purchasedAt()),purchase.refunded(),purchase.sandbox());
            }
        }
        boolean sandboxRejected = customer.subscriptions().stream()
                .anyMatch(subscription -> subscription.sandbox()
                        && isActive(subscription, now)
                        && !(sandboxAllowed && BillingProduct.fromProductId(subscription.productId()).orElse(null) == BillingProduct.BUSINESS)
                        && BillingProduct.fromProductId(subscription.productId())
                            .map(product -> selected.isEmpty()
                                    || product.getPlan().ordinal() > selected.get().product().getPlan().ordinal())
                            .orElse(false));
        return sandboxRejected ? "SANDBOX_REJECTED"
                : selected.isPresent() ? "VERIFIED" : "NO_ACTIVE_SUBSCRIPTION";
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
        if (subscription.refunded() || subscription.purchasedAt() == null) {
            return false;
        }

        Instant accessEndsAt = subscription.accessEndsAt();
        return accessEndsAt != null && accessEndsAt.isAfter(now);
    }

    private BillingOverviewResponse buildOverview(User user) {
        return buildOverview(user, "NOT_CHECKED");
    }

    private BillingOverviewResponse buildOverview(User user, String verification) {
        BillingSubscription billingSubscription = subscriptionRepository
                .findByUserId(user.getId())
                .orElse(null);
        SubscriptionPlan effectivePlan =
                subscriptionService.getEffectivePlan(user);
        BillingSubscriptionStatus effectiveStatus =
                billingSubscription == null ? BillingSubscriptionStatus.NONE
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
                        : billingSubscription.getLastSyncedAt(),
                verification
        );

        return new BillingOverviewResponse(status, catalog());
    }

    private List<BillingPlanResponse> catalog() {
        List<BillingPlanResponse> plans = new ArrayList<>();
        plans.add(new BillingPlanResponse(
                SubscriptionPlan.FREE,
                "Kişisel kredi hesabı",
                "Süresiz kredi paketleriyle kullandığınız kadar ödeyin",
                null,
                null,
                BigDecimal.ZERO,
                "TRY",
                false,
                List.of("1 aktif araç", "Uygun cihaz ve hesaplara bir kez 1 analiz + 2 asistan kredisi")
        ));

        for (BillingProduct product : BillingProduct.values()) {
            if (creditWallets != null && product.getPlan() != SubscriptionPlan.BUSINESS) continue;
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

        return candidates.stream().sorted()
                .map(userRepository::findByBillingCustomerIdForUpdate)
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
