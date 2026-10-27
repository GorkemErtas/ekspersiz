package com.gorkem.vehicle_inspector.service.billing;

import com.gorkem.vehicle_inspector.entity.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/** Operator-managed immutable customer IDs; never email, aliases or client attributes. */
@Component
public class BillingSandboxPolicy {
    private final Set<String> customers;

    public BillingSandboxPolicy(@Value("${application.billing.sandbox-customer-ids:}") String ids) {
        customers = Arrays.stream(ids.split(","))
                .map(String::trim).filter(id -> !id.isEmpty())
                .map(id -> {
                    if (!UUID.fromString(id).toString().equals(id))
                        throw new IllegalArgumentException("Sandbox customer IDs must be canonical UUIDs");
                    return id;
                }).collect(Collectors.toUnmodifiableSet());
    }

    public boolean allows(User user) {
        return user != null && allowsCustomerId(user.getBillingCustomerId());
    }

    public boolean allowsCustomerId(String customerId) {
        return customerId != null && customers.contains(customerId);
    }

    public boolean allowsPurchase(User user, String productId) {
        var product = CreditCatalog.find(productId);
        // Company consumables stay production-only. Test subscriptions use BusinessBillingPolicy.
        return allows(user) && product != null && !product.business();
    }

    /** Lifetime delivery budget per canonical tester; refunds and renewals never reset it. */
    public long personalCreditLimit(String resource) {
        return switch (resource) {
            case "ANALYSIS" -> 100;
            case "ASSISTANT" -> 200;
            case "SLOT" -> 10;
            default -> 0;
        };
    }
}
