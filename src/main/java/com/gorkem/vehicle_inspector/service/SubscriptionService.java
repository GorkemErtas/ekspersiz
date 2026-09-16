package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import com.gorkem.vehicle_inspector.repository.RewardedAnalysisSessionRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.Clock;

@Service
public class SubscriptionService {

    private static final int FREE_MONTHLY_ANALYSIS_LIMIT = 1;
    private static final int PLUS_MONTHLY_ANALYSIS_LIMIT = 5;
    private static final int PRO_MONTHLY_ANALYSIS_LIMIT = 20;
    private static final int BUSINESS_MONTHLY_ANALYSIS_LIMIT = 100;

    private static final int FREE_VEHICLE_LIMIT = 1;
    private static final int PLUS_VEHICLE_LIMIT = 3;
    private static final int PRO_VEHICLE_LIMIT = 10;
    private static final int BUSINESS_VEHICLE_LIMIT = 50;

    private final DamageInspectionRepository
            inspectionRepository;

    private final VehicleRepository
            vehicleRepository;
    private final Clock clock;
    private final RewardedAnalysisSessionRepository rewardedSessions;

    public SubscriptionService(
            DamageInspectionRepository inspectionRepository,
            VehicleRepository vehicleRepository,
            RewardedAnalysisSessionRepository rewardedSessions,
            Clock clock
    ) {
        this.inspectionRepository =
                inspectionRepository;

        this.vehicleRepository =
                vehicleRepository;
        this.rewardedSessions = rewardedSessions;
        this.clock = clock;
    }

    public SubscriptionPlan getEffectivePlan(
            User user
    ) {
        if (user.getSubscriptionPlan() == null) {
            return SubscriptionPlan.FREE;
        }

        if (user.getSubscriptionPlan()
                == SubscriptionPlan.FREE) {

            return SubscriptionPlan.FREE;
        }

        LocalDateTime expiresAt =
                user.getSubscriptionExpiresAt();

        if (expiresAt != null
                && !expiresAt.isAfter(
                LocalDateTime.now(clock)
        )) {

            return SubscriptionPlan.FREE;
        }

        return user.getSubscriptionPlan();
    }

    public void validatePersonalMonthlyAnalysisLimit(
            User user,
            LocalDateTime analysisStartedAt
    ) {

        SubscriptionPlan plan =
                getEffectivePlan(user);

        int limit = monthlyAnalysisLimit(plan);

        LocalDateTime start = analysisStartedAt
                .toLocalDate()
                .withDayOfMonth(1)
                .atStartOfDay();

        LocalDateTime end = start.plusMonths(1);

        long used =
                inspectionRepository
                        .countPersonalAnalysesBetween(
                                user.getId(),
                                start,
                                end
                        );

        boolean rewardedClaimed = plan == SubscriptionPlan.FREE
                && rewardedSessions.existsByUserIdAndMonthStartAndClaimedAtIsNotNull(
                user.getId(), start.toLocalDate());
        int effectiveLimit = limit + (rewardedClaimed ? 1 : 0);

        if (used >= effectiveLimit) {
            if (plan == SubscriptionPlan.FREE && !rewardedClaimed) {
                throw new IllegalStateException(
                        "Bu ayki ücretsiz analiz hakkınızı kullandınız."
                );
            }
            throw new IllegalStateException(
                    "Aylık analiz limitinize ulaştınız. "
                            + "Mevcut plan: "
                            + plan
                            + ", aylık limit: "
                            + effectiveLimit
                            + "."
            );
        }
    }

    public void validateBusinessMonthlyAnalysisLimit(
            BusinessAccount businessAccount,
            LocalDateTime analysisStartedAt
    ) {
        LocalDateTime start = analysisStartedAt
                .toLocalDate()
                .withDayOfMonth(1)
                .atStartOfDay();

        long used = inspectionRepository.countBusinessAnalysesBetween(
                businessAccount.getId(),
                start,
                start.plusMonths(1)
        );
        if (used >= BUSINESS_MONTHLY_ANALYSIS_LIMIT) {
            throw new IllegalStateException(
                    "Şirketin aylık analiz limitine ulaşıldı. Aylık ortak limit: "
                            + BUSINESS_MONTHLY_ANALYSIS_LIMIT + "."
            );
        }
    }

    public void validateVehicleLimit(
            User user
    ) {

        SubscriptionPlan plan =
                getEffectivePlan(user);

        int limit =
                switch (plan) {
                    case FREE ->
                            FREE_VEHICLE_LIMIT;
                    case PLUS ->
                            PLUS_VEHICLE_LIMIT;
                    case PRO ->
                            PRO_VEHICLE_LIMIT;
                    case BUSINESS ->
                            throw new IllegalStateException(
                                    "Business araç limiti şirket hesabı üzerinden hesaplanmalıdır."
                            );
                };

        long vehicleCount =
                vehicleRepository
                        .countByUserIdAndArchivedFalse(
                                user.getId()
                        );

        if (vehicleCount >= limit) {
            throw new IllegalStateException(
                    "Araç limitinize ulaştınız. "
                            + "Mevcut plan: "
                            + plan
                            + ", araç limiti: "
                            + limit
                            + "."
            );
        }
    }

    public void validateBusinessVehicleLimit(
            BusinessAccount businessAccount
    ) {
        long vehicleCount =
                vehicleRepository
                        .countByBusinessAccountIdAndArchivedFalse(
                                businessAccount.getId()
                        );

        if (vehicleCount >= BUSINESS_VEHICLE_LIMIT) {
            throw new IllegalStateException(
                    "Şirket araç limitine ulaştınız. "
                            + "Business araç limiti: "
                            + BUSINESS_VEHICLE_LIMIT
                            + "."
            );
        }
    }

    public int monthlyAnalysisLimit(SubscriptionPlan plan) {
        return switch (plan) {
            case FREE -> FREE_MONTHLY_ANALYSIS_LIMIT;
            case PLUS -> PLUS_MONTHLY_ANALYSIS_LIMIT;
            case PRO -> PRO_MONTHLY_ANALYSIS_LIMIT;
            case BUSINESS -> throw new IllegalStateException(
                    "Business analiz limiti şirket hesabı üzerinden hesaplanmalıdır.");
        };
    }

    public int businessMonthlyAnalysisLimit() {
        return BUSINESS_MONTHLY_ANALYSIS_LIMIT;
    }
}
