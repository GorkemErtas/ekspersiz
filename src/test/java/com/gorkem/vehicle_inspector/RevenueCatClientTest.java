package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.client.RevenueCatClient;
import org.junit.jupiter.api.Test;
import org.springframework.http.*;
import org.springframework.web.client.RestTemplate;
import tools.jackson.databind.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class RevenueCatClientTest {
    @Test void reconciliationUsesStoreIdAndPreservesRefunds() {
        var http=mock(RestTemplate.class);
        var body=new ObjectMapper().readTree("""
            {"subscriber":{"non_subscriptions":{"eksper_analysis_5":[
              {"id":"rc-internal-id","store_transaction_id":"GPA.store-order","purchase_date":"2026-10-19T09:00:00Z","refunded_at":"2026-10-19T10:00:00Z"},
              {"id":"no-store-id","purchase_date":"2026-10-19T09:00:00Z"}
            ]}}}
            """);
        when(http.exchange(anyString(),eq(HttpMethod.GET),any(HttpEntity.class),eq(JsonNode.class),eq("customer")))
                .thenReturn(ResponseEntity.ok(body));
        var result=new RevenueCatClient(http,"https://api.revenuecat.com/v1","test-key").getCustomer("customer");
        assertEquals(1,result.purchases().size());
        assertEquals("GPA.store-order",result.purchases().getFirst().transactionId());
        assertTrue(result.purchases().getFirst().refunded());
    }
}
