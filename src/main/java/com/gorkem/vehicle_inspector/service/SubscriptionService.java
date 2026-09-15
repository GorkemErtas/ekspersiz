package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.Clock;

@Service
public class SubscriptionService {

    private static final int FREE_DAILY_INSPECTION_LIMIT = 3;
    private static final int PLUS_DAILY_INSPECTION_LIMIT = 15;
    private static final int BUSINESS_DAILY_INSPECTION_LIMIT = 100;

    private static final int FREE_VEHICLE_LIMIT = 1;
    private static final int PLUS_VEHICLE_LIMIT = 5;
    private static final int BUSINESS_VEHICLE_LIMIT = 50;

    private final DamageInspectionRepository
            inspectionRepository;

    private final VehicleRepository
            vehicleRepository;
    private final Clock clock;

    public SubscriptionService(
            DamageInspectionRepository inspectionRepository,
            VehicleRepository vehicleRepository,
            Clock clock
    ) {
        this.inspectionRepository =
                inspectionRepository;

        this.vehicleRepository =
                vehicleRepository;
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

    public void validateInspectionLimit(
            User user
    ) {

        SubscriptionPlan plan =
                getEffectivePlan(user);

        if (plan == SubscriptionPlan.PRO) {
            return;
        }

        int limit =
                switch (plan) {
                    case FREE ->
                            FREE_DAILY_INSPECTION_LIMIT;
                    case PLUS ->
                            PLUS_DAILY_INSPECTION_LIMIT;
                    case PRO ->
                            Integer.MAX_VALUE;
                    case BUSINESS ->
                            throw new IllegalStateException(
                                    "Business analiz limiti şirket hesabı üzerinden hesaplanmalıdır."
                            );
                };

        LocalDate today =
                LocalDate.now(clock);

        LocalDateTime start =
                today.atStartOfDay();

        LocalDateTime end =
                today.plusDays(1)
                        .atStartOfDay();

        long used =
                inspectionRepository
                        .countPersonalAnalysesBetween(
                                user.getId(),
                                start,
                                end
                        );

        if (used >= limit) {
            throw new IllegalStateException(
                    "Günlük analiz limitinize ulaştınız. "
                            + "Mevcut plan: "
                            + plan
                            + ", günlük limit: "
                            + limit
                            + "."
            );
        }
    }

    public void validateBusinessInspectionLimit(BusinessAccount businessAccount) {
        validateBusinessInspectionLimit(businessAccount, LocalDateTime.now(clock));
    }

    public void validateBusinessInspectionLimit(
            BusinessAccount businessAccount,
            LocalDateTime analysisStartedAt
    ) {
        LocalDate today = analysisStartedAt.toLocalDate();
        long used = inspectionRepository.countBusinessAnalysesBetween(
                businessAccount.getId(),
                today.atStartOfDay(),
                today.plusDays(1).atStartOfDay()
        );
        if (used >= BUSINESS_DAILY_INSPECTION_LIMIT) {
            throw new IllegalStateException(
                    "Şirketin günlük analiz limitine ulaşıldı. Günlük ortak limit: "
                            + BUSINESS_DAILY_INSPECTION_LIMIT + "."
            );
        }
    }

    public void validateVehicleLimit(
            User user
    ) {

        SubscriptionPlan plan =
                getEffectivePlan(user);

        if (plan == SubscriptionPlan.PRO) {
            return;
        }

        int limit =
                switch (plan) {
                    case FREE ->
                            FREE_VEHICLE_LIMIT;
                    case PLUS ->
                            PLUS_VEHICLE_LIMIT;
                    case PRO ->
                            Integer.MAX_VALUE;
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
}
