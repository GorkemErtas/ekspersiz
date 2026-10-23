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
        return user != null && customers.contains(user.getBillingCustomerId());
    }

    public boolean allowsPurchase(User user, String productId) {
        var product = CreditCatalog.find(productId);
        // Shared company wallets and subscription entitlements remain production-only.
        return allows(user) && product != null && !product.business();
    }
}
