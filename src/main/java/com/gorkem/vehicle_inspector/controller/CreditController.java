package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.CreditWalletService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/credits")
public class CreditController {
    private final CreditWalletService credits;
    private final BusinessContextService context;
    public CreditController(CreditWalletService credits,BusinessContextService context) { this.credits=credits;this.context=context; }
    @GetMapping
    public CreditWalletService.Overview overview(Authentication auth) { return credits.overview(context.requireUser(auth.getName())); }
    @PostMapping("/purchase-intents/{productId}")
    public Map<String,String> prepare(@PathVariable String productId,Authentication auth) {
        return Map.of("id",credits.preparePurchase(context.requireUser(auth.getName()),productId).toString());
    }
    @GetMapping("/purchases/{transaction}")
    public Map<String,Boolean> purchase(@PathVariable String transaction,Authentication auth) {
        return Map.of("confirmed",credits.purchaseConfirmed(context.requireUser(auth.getName()),transaction));
    }
}
