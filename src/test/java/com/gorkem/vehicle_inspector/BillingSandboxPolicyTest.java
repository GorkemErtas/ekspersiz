package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.service.billing.BillingSandboxPolicy;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.junit.jupiter.api.Assertions.*;

class BillingSandboxPolicyTest {
    @ParameterizedTest
    @ValueSource(strings={"*","true","test@example.com","$RCAnonymousID:123","1-1-1-1-1","A0C8EF15-5087-4C83-8DA2-C8F336332E70"})
    void invalidOrBroadAuthorizationFailsAtStartup(String value) {
        assertThrows(IllegalArgumentException.class,() -> new BillingSandboxPolicy(value));
    }

    @Test void onlyServerAssignedCanonicalIdsAuthorizeTestAccounts() {
        var authorized=new User("Tester","test@example.com","unused");
        var other=new User("Other","test@example.com","unused");
        var policy=new BillingSandboxPolicy(" , "+authorized.getBillingCustomerId()+", ");
        assertTrue(policy.allows(authorized));
        assertFalse(policy.allows(other));
        assertFalse(policy.allows(null));
        assertFalse(new BillingSandboxPolicy("").allows(authorized));
        assertTrue(policy.allowsPurchase(authorized,"eksper_analysis_5"));
        assertFalse(policy.allowsPurchase(authorized,"eksper_analysis_5_business"));
    }
}
