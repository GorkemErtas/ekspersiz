package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.response.BillingOverviewResponse;
import com.gorkem.vehicle_inspector.service.BillingService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/billing")
public class BillingController {

    private final BillingService billingService;

    public BillingController(BillingService billingService) {
        this.billingService = billingService;
    }

    @GetMapping
    public ResponseEntity<BillingOverviewResponse> getOverview(
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                billingService.getOverview(authentication.getName())
        );
    }

    @PostMapping("/sync")
    public ResponseEntity<BillingOverviewResponse> sync(
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                billingService.sync(authentication.getName())
        );
    }

    @PostMapping("/revenuecat/webhook")
    public ResponseEntity<Void> revenueCatWebhook(
            @RequestHeader(
                    value = HttpHeaders.AUTHORIZATION,
                    required = false
            ) String authorization,
            @RequestHeader(
                    value = "X-RevenueCat-Webhook-Signature",
                    required = false
            ) String signature,
            @RequestBody String rawBody
    ) {
        billingService.processRevenueCatWebhook(
                authorization,
                signature,
                rawBody
        );

        return ResponseEntity.noContent().build();
    }
}
