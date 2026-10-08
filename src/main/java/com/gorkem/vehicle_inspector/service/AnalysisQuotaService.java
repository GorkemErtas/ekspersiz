package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.AnalysisQuotaResponse;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.AnalysisUsageRepository;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Service
public class AnalysisQuotaService {

    private final BusinessContextService businessContext;
    private final SubscriptionService subscriptions;
    private final AnalysisUsageRepository usages;
    private final Clock clock;
    private final AnalysisCreditService analysisCreditService;

    @Autowired
    public AnalysisQuotaService(
            BusinessContextService businessContext,
            SubscriptionService subscriptions,
            AnalysisUsageRepository usages,
            Clock clock,
            AnalysisCreditService analysisCreditService
    ) {
        this.businessContext = businessContext;
        this.subscriptions = subscriptions;
        this.usages = usages;
        this.clock = clock;
        this.analysisCreditService = analysisCreditService;
    }

    public AnalysisQuotaService(
            BusinessContextService businessContext,
            SubscriptionService subscriptions,
            AnalysisUsageRepository usages,
            Clock clock
    ) {
        this(businessContext, subscriptions, usages, clock, null);
    }

    @Transactional(readOnly = true)
    public AnalysisQuotaResponse getQuota(String email) {
        User user = businessContext.requireUser(email);
        LocalDateTime start = monthStart();
        LocalDateTime end = start.plusMonths(1);

        if (businessContext.findMembership(user).isPresent()) {
            BusinessAccount business =
                    businessContext.requireBusinessAccount(user);

            int limit =
                    subscriptions.businessMonthlyAnalysisLimit();

            long used =
                    usages.countByBusinessAccount_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                            business.getId(),
                            start,
                            end
                    );

            return response(
                    SubscriptionPlan.BUSINESS,
                    used,
                    limit
            );
        }

        SubscriptionPlan plan = subscriptions.getEffectivePlan(user);
        int limit = plan == SubscriptionPlan.BUSINESS
                ? 1 : subscriptions.monthlyAnalysisLimit(plan);
        long used = usages.countByUser_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                user.getId(), start, end);
        long monthlyRemaining = Math.max(0, limit - used);
        long legacyCredits = analysisCreditService == null
                ? 0 : analysisCreditService.getBalance(user);

        return new AnalysisQuotaResponse(
                plan,
                used,
                limit,
                monthlyRemaining + legacyCredits,
                monthlyRemaining,
                legacyCredits
        );
    }

    private AnalysisQuotaResponse response(
            SubscriptionPlan plan,
            long used,
            int limit
    ) {
        long remaining = Math.max(0, limit - used);
        return new AnalysisQuotaResponse(
                plan,
                used,
                limit,
                remaining,
                remaining,
                0
        );
    }

    private LocalDateTime monthStart() {
        return LocalDate.now(clock)
                .withDayOfMonth(1)
                .atStartOfDay();
    }
}