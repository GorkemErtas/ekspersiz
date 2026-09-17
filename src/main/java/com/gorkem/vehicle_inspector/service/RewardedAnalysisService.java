package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.AnalysisQuotaResponse;
import com.gorkem.vehicle_inspector.dto.response.RewardedAdSessionResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.InvalidRewardCallbackException;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.*;
import java.util.UUID;

@Service
public class RewardedAnalysisService {
    private static final Logger log = LoggerFactory.getLogger(RewardedAnalysisService.class);
    private final BusinessContextService businessContext;
    private final SubscriptionService subscriptions;
    private final DamageInspectionRepository inspections;
    private final RewardedAnalysisSessionRepository sessions;
    private final UserRepository users;
    private final AdMobSsvVerifier verifier;
    private final Clock clock;

    public RewardedAnalysisService(BusinessContextService businessContext,
                                   SubscriptionService subscriptions,
                                   DamageInspectionRepository inspections,
                                   RewardedAnalysisSessionRepository sessions,
                                   UserRepository users, AdMobSsvVerifier verifier,
                                   Clock clock) {
        this.businessContext = businessContext;
        this.subscriptions = subscriptions;
        this.inspections = inspections;
        this.sessions = sessions;
        this.users = users;
        this.verifier = verifier;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public AnalysisQuotaResponse quota(String email) {
        User user = businessContext.requireUser(email);
        LocalDateTime start = monthStart();
        if (businessContext.findMembership(user).isPresent()) {
            BusinessAccount business = businessContext.requireBusinessAccount(user);
            int limit = subscriptions.businessMonthlyAnalysisLimit();
            long used = inspections.countBusinessAnalysesBetween(
                    business.getId(), start, start.plusMonths(1));
            return new AnalysisQuotaResponse(SubscriptionPlan.BUSINESS, used, limit,
                    false, false, limit, Math.max(0, limit - used));
        }

        SubscriptionPlan plan = subscriptions.getEffectivePlan(user);
        if (plan == SubscriptionPlan.BUSINESS) {
            return new AnalysisQuotaResponse(plan, 0, 0, false, false, 0, 0);
        }
        int baseLimit = subscriptions.monthlyAnalysisLimit(plan);
        long used = inspections.countPersonalAnalysesBetween(
                user.getId(), start, start.plusMonths(1));
        boolean rewardedClaimed = plan == SubscriptionPlan.FREE
                && sessions.existsByUserIdAndMonthStartAndClaimedAtIsNotNull(
                user.getId(), start.toLocalDate());
        int total = baseLimit + (rewardedClaimed ? 1 : 0);
        boolean eligible = plan == SubscriptionPlan.FREE && used >= baseLimit
                && !rewardedClaimed;
        return new AnalysisQuotaResponse(plan, used, baseLimit, rewardedClaimed,
                eligible, total, Math.max(0, total - used));
    }

    @Transactional
    public RewardedAdSessionResponse createSession(String email) {
        User user = businessContext.requireUser(email);
        if (businessContext.findMembership(user).isPresent()
                || subscriptions.getEffectivePlan(user) != SubscriptionPlan.FREE) {
            throw new IllegalStateException("Ödüllü analiz yalnızca kişisel FREE plan için kullanılabilir.");
        }
        user = users.findByIdForUpdate(user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Kullanıcı bulunamadı."));
        LocalDateTime start = monthStart();
        long used = inspections.countPersonalAnalysesBetween(
                user.getId(), start, start.plusMonths(1));
        if (used < subscriptions.monthlyAnalysisLimit(SubscriptionPlan.FREE)) {
            throw new IllegalStateException("Önce bu ayki ücretsiz analiz hakkınızı kullanabilirsiniz.");
        }
        LocalDate month = start.toLocalDate();
        RewardedAnalysisSession session = sessions.findByUserIdAndMonthStart(user.getId(), month)
                .orElse(null);
        if (session != null && session.getClaimedAt() != null) {
            throw new IllegalStateException("Bu ayki ödüllü analiz hakkı zaten kazanıldı.");
        }
        LocalDateTime now = LocalDateTime.now(clock);
        if (session == null) {
            String token = UUID.randomUUID().toString();
            session = new RewardedAnalysisSession(user, month, token, now.plusMinutes(30), now);
        } else if (!now.isBefore(session.getExpiresAt())) {
            String token = UUID.randomUUID().toString();
            session.rotate(token, now.plusMinutes(30));
        }
        String userId = user.ensureBillingCustomerId();
        users.save(user);
        RewardedAnalysisSession saved = sessions.save(session);
        log.info("Reward session ready: sessionId={}, tokenId={}, userId={}",
                saved.getId(), shortId(saved.getToken()), shortId(userId));
        return new RewardedAdSessionResponse(saved.getToken(), userId, saved.getExpiresAt());
    }

    @Transactional
    public void acceptSsv(String rawQuery, String customData, String userId,
                          String transactionId, long timestamp) {
        log.info("AdMob SSV received: tokenId={}, transactionId={}",
                shortId(customData), shortId(transactionId));
        verifier.verify(rawQuery);
        if (sessions.existsByTransactionId(transactionId)) {
            log.info("AdMob SSV already processed: transactionId={}", shortId(transactionId));
            return;
        }
        RewardedAnalysisSession session = sessions.findByTokenForUpdate(customData)
                .orElseThrow(() -> new InvalidRewardCallbackException("Ödül oturumu bulunamadı."));
        if (!session.getUser().ensureBillingCustomerId().equals(userId)) {
            throw new InvalidRewardCallbackException("Ödül kullanıcı bilgisi eşleşmiyor.");
        }
        if (session.getClaimedAt() != null) {
            if (transactionId.equals(session.getTransactionId())) return;
            throw new InvalidRewardCallbackException("Ödül oturumu daha önce kullanıldı.");
        }
        LocalDateTime now = LocalDateTime.now(clock);
        if (now.isAfter(session.getExpiresAt())
                || !session.getMonthStart().equals(monthStart().toLocalDate())) {
            throw new InvalidRewardCallbackException("Ödül oturumunun süresi doldu.");
        }
        Instant callbackTime = Instant.ofEpochMilli(timestamp);
        if (callbackTime.isAfter(Instant.now(clock).plusSeconds(60))
                || callbackTime.isBefore(Instant.now(clock).minus(Duration.ofHours(1)))) {
            throw new InvalidRewardCallbackException("Ödül zamanı geçersiz.");
        }
        session.claim(transactionId, now);
        sessions.save(session);
        log.info("Reward verified and claimed: sessionId={}, tokenId={}",
                session.getId(), shortId(session.getToken()));
    }

    private LocalDateTime monthStart() {
        return LocalDate.now(clock).withDayOfMonth(1).atStartOfDay();
    }

    private static String shortId(String value) {
        if (value == null || value.isBlank()) return "-";
        return value.substring(0, Math.min(8, value.length()));
    }
}
