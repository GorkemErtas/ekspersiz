package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.response.AnalysisQuotaResponse;
import com.gorkem.vehicle_inspector.dto.response.RewardedAdSessionResponse;
import com.gorkem.vehicle_inspector.service.RewardedAnalysisService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/rewards/analysis")
public class RewardedAnalysisController {
    private final RewardedAnalysisService rewards;

    public RewardedAnalysisController(RewardedAnalysisService rewards) {
        this.rewards = rewards;
    }

    @GetMapping
    public AnalysisQuotaResponse quota(Authentication authentication) {
        return rewards.quota(authentication.getName());
    }

    @PostMapping("/session")
    public RewardedAdSessionResponse createSession(Authentication authentication) {
        return rewards.createSession(authentication.getName());
    }

    @GetMapping("/admob/ssv")
    public ResponseEntity<Void> admobSsv(
            HttpServletRequest request,
            @RequestParam("custom_data") String customData,
            @RequestParam("user_id") String userId,
            @RequestParam("transaction_id") String transactionId,
            @RequestParam long timestamp) {
        rewards.acceptSsv(request.getQueryString(), customData, userId,
                transactionId, timestamp);
        return ResponseEntity.ok().build();
    }
}
