package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.AnalysisQuotaResponse;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Service
public class AnalysisQuotaService {

    private final BusinessContextService businessContext;
    private final SubscriptionService subscriptions;
    private final DamageInspectionRepository inspections;
    private final Clock clock;

    public AnalysisQuotaService(
            BusinessContextService businessContext,
            SubscriptionService subscriptions,
            DamageInspectionRepository inspections,
            Clock clock
    ) {
        this.businessContext = businessContext;
        this.subscriptions = subscriptions;
        this.inspections = inspections;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public AnalysisQuotaResponse getQuota(String email) {
        User user = businessContext.requireUser(email);
        LocalDateTime start = monthStart();

        if (businessContext.findMembership(user).isPresent()) {
            BusinessAccount business =
                    businessContext.requireBusinessAccount(user);
            int limit = subscriptions.businessMonthlyAnalysisLimit();
            long used = inspections.countBusinessAnalysesBetween(
                    business.getId(),
                    start,
                    start.plusMonths(1)
            );
            return response(SubscriptionPlan.BUSINESS, used, limit);
        }

        SubscriptionPlan plan = subscriptions.getEffectivePlan(user);
        if (plan == SubscriptionPlan.BUSINESS) {
            return response(plan, 0, 0);
        }

        int limit = subscriptions.monthlyAnalysisLimit(plan);
        long used = inspections.countPersonalAnalysesBetween(
                user.getId(),
                start,
                start.plusMonths(1)
        );
        return response(plan, used, limit);
    }

    private AnalysisQuotaResponse response(
            SubscriptionPlan plan,
            long used,
            int limit
    ) {
        return new AnalysisQuotaResponse(
                plan,
                used,
                limit,
                Math.max(0, limit - used)
        );
    }

    private LocalDateTime monthStart() {
        return LocalDate.now(clock)
                .withDayOfMonth(1)
                .atStartOfDay();
    }
}
