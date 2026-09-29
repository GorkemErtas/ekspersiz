package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;

@Service
public class AnalysisCreditService {

    private static final int FREE_MONTHLY_REPORT_LIMIT = 1;

    private final AnalysisCreditTransactionRepository credits;
    private final AnalysisUsageRepository usages;
    private final UserRepository users;
    private final BusinessAccountRepository businesses;
    private final BusinessContextService businessContext;
    private final SubscriptionService subscriptions;
    private final Clock clock;

    public AnalysisCreditService(
            AnalysisCreditTransactionRepository credits,
            AnalysisUsageRepository usages,
            UserRepository users,
            BusinessAccountRepository businesses,
            BusinessContextService businessContext,
            SubscriptionService subscriptions,
            Clock clock
    ) {
        this.credits = credits;
        this.usages = usages;
        this.users = users;
        this.businesses = businesses;
        this.businessContext = businessContext;
        this.subscriptions = subscriptions;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public long getBalance(User user) {
        return Math.max(0, credits.balanceByUserId(user.getId()));
    }

    @Transactional
    public void grantPurchase(
            User user,
            String productId,
            String transactionId
    ) {
        int amount = creditsForProduct(productId);
        if (amount == 0 || transactionId == null || transactionId.isBlank()
                || credits.existsByExternalTransactionId(transactionId)) {
            return;
        }

        User lockedUser = users.findByIdForUpdate(user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Kullanıcı bulunamadı."));

        if (credits.existsByExternalTransactionId(transactionId)) {
            return;
        }

        credits.save(AnalysisCreditTransaction.purchase(
                lockedUser,
                amount,
                productId,
                transactionId,
                LocalDateTime.now(clock)
        ));
    }

    @Transactional
    public void revokePurchase(
            User user,
            String productId,
            String transactionId
    ) {
        int amount = creditsForProduct(productId);
        String refundId = transactionId == null ? null : "refund:" + transactionId;
        if (amount == 0 || refundId == null || transactionId.isBlank()
                || credits.existsByExternalTransactionId(refundId)) {
            return;
        }

        User lockedUser = users.findByIdForUpdate(user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Kullanıcı bulunamadı."));

        if (!credits.existsByExternalTransactionId(transactionId)
                || credits.existsByExternalTransactionId(refundId)) {
            return;
        }

        credits.save(AnalysisCreditTransaction.refund(
                lockedUser,
                amount,
                productId,
                transactionId,
                LocalDateTime.now(clock)
        ));
    }

    @Transactional
    public void grantReportAccess(DamageInspection inspection, User user) {
        if (inspection.isReportAccessGranted()) {
            return;
        }

        LocalDateTime now = LocalDateTime.now(clock);
        BusinessAccount business = inspection.getVehicle().getBusinessAccount();

        if (business != null) {
            BusinessAccount active = businessContext.requireBusinessAccount(user);
            if (!active.getId().equals(business.getId())) {
                throw new ResourceNotFoundException("Şirket aracı bulunamadı.");
            }
            BusinessAccount locked = businesses.findByIdForUpdate(business.getId())
                    .orElseThrow(() -> new ResourceNotFoundException("Şirket bulunamadı."));
            subscriptions.validateBusinessMonthlyAnalysisLimit(locked, now);
            subscriptions.recordBusinessAnalysisUsage(locked, now);
            inspection.grantReportAccess(ReportAccessSource.BUSINESS);
            return;
        }

        User lockedUser = users.findByIdForUpdate(user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Kullanıcı bulunamadı."));

        LocalDateTime start = now.toLocalDate().withDayOfMonth(1).atStartOfDay();
        long freeUsed = usages
                .countByUser_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                        lockedUser.getId(), start, start.plusMonths(1));

        if (freeUsed < FREE_MONTHLY_REPORT_LIMIT) {
            subscriptions.recordPersonalAnalysisUsage(lockedUser, now);
            inspection.grantReportAccess(ReportAccessSource.FREE_MONTHLY);
            return;
        }

        if (credits.balanceByUserId(lockedUser.getId()) <= 0) {
            throw new IllegalStateException(
                    "Detaylı AI raporu için analiz hakkınız bulunmuyor. Tek analiz veya avantajlı paket satın alabilirsiniz."
            );
        }

        credits.save(AnalysisCreditTransaction.consume(
                lockedUser,
                inspection,
                now
        ));
        inspection.grantReportAccess(ReportAccessSource.PURCHASED_CREDIT);
    }

    private int creditsForProduct(String productId) {
        if (productId == null) {
            return 0;
        }
        return switch (productId) {
            case "analysis_1" -> 1;
            case "analysis_3" -> 3;
            case "analysis_10" -> 10;
            default -> 0;
        };
    }
}
