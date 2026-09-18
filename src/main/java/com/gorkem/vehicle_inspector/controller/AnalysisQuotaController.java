package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.response.AnalysisQuotaResponse;
import com.gorkem.vehicle_inspector.service.AnalysisQuotaService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/analysis-quota")
public class AnalysisQuotaController {

    private final AnalysisQuotaService analysisQuotaService;

    public AnalysisQuotaController(
            AnalysisQuotaService analysisQuotaService
    ) {
        this.analysisQuotaService = analysisQuotaService;
    }

    @GetMapping
    public AnalysisQuotaResponse getQuota(
            Authentication authentication
    ) {
        return analysisQuotaService.getQuota(
                authentication.getName()
        );
    }
}
