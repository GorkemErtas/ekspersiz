package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.AiAssistantEntitlementResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.jdbc.core.JdbcTemplate;
import java.time.*;
import java.util.UUID;

@Service
public class AiAssistantEntitlementService {
    public static final int DAILY_LIMIT = 3;
    public static final int OUT_OF_SCOPE_LOCK_THRESHOLD = 3;
    private final Duration reservationTtl;
    private final SubscriptionService subscriptions;
    private final JdbcTemplate jdbc;

    private final AiAssistantAccessRepository accessRepository;
    private final AiAssistantDailyUsageRepository usageRepository;
    private final AiAssistantQuotaReservationRepository reservationRepository;
    private final BusinessContextService businessContext;
    private final Clock clock;

    @Autowired
    public AiAssistantEntitlementService(AiAssistantAccessRepository accessRepository,
            AiAssistantDailyUsageRepository usageRepository,
            AiAssistantQuotaReservationRepository reservationRepository,
            BusinessContextService businessContext,
            SubscriptionService subscriptions,
            JdbcTemplate jdbc,
            @Value("${application.ai-assistant.usage-zone:Europe/Istanbul}") String usageZone,
            @Value("${application.ai-assistant.reservation-ttl:PT5M}") Duration reservationTtl) {
        this(accessRepository, usageRepository, reservationRepository,
                businessContext, subscriptions, jdbc, Clock.system(ZoneId.of(usageZone)), reservationTtl);
    }

    AiAssistantEntitlementService(AiAssistantAccessRepository accessRepository,
            AiAssistantDailyUsageRepository usageRepository,
            AiAssistantQuotaReservationRepository reservationRepository,
            BusinessContextService businessContext, Clock clock, Duration reservationTtl) {
        this(accessRepository, usageRepository, reservationRepository, businessContext, null, null, clock, reservationTtl);
    }

    AiAssistantEntitlementService(AiAssistantAccessRepository accessRepository,
            AiAssistantDailyUsageRepository usageRepository,
            AiAssistantQuotaReservationRepository reservationRepository,
            BusinessContextService businessContext, SubscriptionService subscriptions,
            JdbcTemplate jdbc, Clock clock, Duration reservationTtl) {
        if (reservationTtl == null || reservationTtl.isZero() || reservationTtl.isNegative())
            throw new IllegalArgumentException("AI assistant reservation TTL must be positive.");
        this.accessRepository=accessRepository; this.usageRepository=usageRepository;
        this.reservationRepository=reservationRepository;
        this.businessContext=businessContext; this.clock=clock;
        this.reservationTtl=reservationTtl;
        this.subscriptions=subscriptions;
        this.jdbc=jdbc;
    }

    @Transactional
    public AiAssistantEntitlementResponse startTrial(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantAccess access=accessRepository.findByUserId(user.getId())
                .orElseGet(() -> new AiAssistantAccess(user, now));
        access.startTrial(now); accessRepository.save(access);
        return response(user, access, now);
    }

    @Transactional
    public AiAssistantEntitlementResponse status(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantAccess access=accessRepository.findByUserId(user.getId())
                .orElseGet(() -> accessRepository.save(new AiAssistantAccess(user, now)));
        access.refresh(now);
        return response(user, access, now);
    }

    @Transactional
    public void assertCanAsk(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        assertAccess(user, now);
        BusinessAccount business=businessAccount(user);
        if (business != null) {
            lockBusiness(business);
            releaseExpired(now);
            if (businessUsed(business) + businessReservations(business, now) >= 10)
                throw new IllegalStateException("Şirketin günlük AI Asistan soru hakkı doldu.");
            return;
        }
        AiAssistantDailyUsage usage=findOrCreateUsageForUpdate(user);
        releaseExpired(now);
        if (usage.getSuccessfulQuestions() + activeReservations(user, now) >= dailyLimit(user))
            throw new IllegalStateException("Bugünkü AI Asistan soru hakkınızı kullandınız.");
    }

    @Transactional
    public UUID reserveQuestion(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        assertAccess(user, now);
        BusinessAccount business=businessAccount(user);
        if (business != null) {
            lockBusiness(business);
            releaseExpired(now);
            if (businessUsed(business) + businessReservations(business, now) >= 10)
                throw new IllegalStateException("Şirketin günlük AI Asistan kotası doldu.");
        } else {
            AiAssistantDailyUsage usage=findOrCreateUsageForUpdate(user);
            releaseExpired(now);
            if (usage.getSuccessfulQuestions() + activeReservations(user, now) >= dailyLimit(user))
                throw new IllegalStateException("Günlük AI Asistan kotası doldu.");
        }
        UUID token=UUID.randomUUID();
        AiAssistantQuotaReservation reservation=new AiAssistantQuotaReservation(
                token, user, LocalDate.now(clock), now, now.plus(reservationTtl));
        if (business != null) reservation.assignBusiness(business);
        reservationRepository.save(reservation);
        return token;
    }

    @Transactional
    public void completeReservedQuestion(String email, UUID token) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantQuotaReservation reservation=reservationRepository
                .findOwnedForUpdate(token, user.getId())
                .orElseThrow(() -> new IllegalStateException("AI quota reservation not found."));
        if (reservation.getBusinessAccountId() != null) {
            BusinessAccount business=businessContext.requireBusinessAccount(user);
            if (!business.getId().equals(reservation.getBusinessAccountId()))
                throw new IllegalStateException("Şirket rezervasyonu uyuşmuyor.");
            lockBusiness(business);
            reservation.complete(now);
            jdbc.update("INSERT INTO ai_assistant_business_daily_usage (business_account_id, usage_date, successful_questions) VALUES (?, ?, 1) ON CONFLICT (business_account_id, usage_date) DO UPDATE SET successful_questions = ai_assistant_business_daily_usage.successful_questions + 1, updated_at = CURRENT_TIMESTAMP", business.getId(), java.sql.Date.valueOf(reservation.getUsageDate()));
        } else {
            AiAssistantDailyUsage usage=findOrCreateUsageForUpdate(user);
            reservation.complete(now);
            usage.recordSuccessful(now);
        }
    }

    @Transactional
    public void releaseReservedQuestion(String email, UUID token) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        reservationRepository.findOwnedForUpdate(token, user.getId())
                .ifPresent(reservation -> reservation.release(now));
    }

    @Transactional
    public void recordOutOfScope(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantDailyUsage usage=findOrCreateUsageForUpdate(user); usage.recordOutOfScope(now);
        if (usage.getOutOfScopeAttempts() >= OUT_OF_SCOPE_LOCK_THRESHOLD) {
            AiAssistantAccess access=accessRepository.findByUserId(user.getId()).orElseThrow();
            access.lockUntil(now.plusHours(24), now);
        }
    }

    private BusinessAccount businessAccount(User user) {
        if (subscriptions == null || jdbc == null || !businessContext.isBusinessMember(user)) return null;
        return businessContext.requireBusinessAccount(user);
    }

    private void lockBusiness(BusinessAccount business) {
        jdbc.queryForObject("SELECT id FROM business_accounts WHERE id = ? FOR UPDATE", Long.class, business.getId());
    }

    private int businessUsed(BusinessAccount business) {
        Integer used=jdbc.queryForObject("SELECT COALESCE(SUM(successful_questions), 0) FROM ai_assistant_business_daily_usage WHERE business_account_id = ? AND usage_date = ?", Integer.class, business.getId(), java.sql.Date.valueOf(LocalDate.now(clock)));
        return used == null ? 0 : used;
    }

    private int businessReservations(BusinessAccount business, LocalDateTime now) {
        return Math.toIntExact(reservationRepository.countBusinessActive(business.getId(), LocalDate.now(clock), now));
    }

    private int dailyLimit(User user) {
        if (subscriptions == null) return DAILY_LIMIT;
        return switch (subscriptions.getEffectivePlan(user)) {
            case PRO -> 5;
            case BUSINESS -> 10;
            default -> DAILY_LIMIT;
        };
    }

    private void assertAccess(User user, LocalDateTime now) {
        AiAssistantAccess access=accessRepository.findByUserId(user.getId())
                .orElseGet(() -> accessRepository.save(new AiAssistantAccess(user, now)));
        if (!hasAssistantAccess(user, access, now))
            throw new IllegalStateException("AI Asistan erişiminiz aktif değil.");
    }

    private boolean hasAssistantAccess(User user, AiAssistantAccess access, LocalDateTime now) {
        boolean existingAccess = access.canAsk(now);
        if (access.getLockedUntil() != null && access.getLockedUntil().isAfter(now)) {
            return false;
        }
        if (subscriptions != null) {
            if (businessAccount(user) != null) return true;
            if (subscriptions.getEffectivePlan(user) != SubscriptionPlan.FREE) return true;
        }
        return existingAccess;
    }

    private AiAssistantAccessStatus assistantStatus(User user, AiAssistantAccess access, LocalDateTime now) {
        access.refresh(now);
        if (access.getLockedUntil() != null && access.getLockedUntil().isAfter(now)) {
            return AiAssistantAccessStatus.LOCKED;
        }
        if (subscriptions != null && (businessAccount(user) != null
                || subscriptions.getEffectivePlan(user) != SubscriptionPlan.FREE)) {
            return AiAssistantAccessStatus.ACTIVE;
        }
        return access.getStatus();
    }

    private AiAssistantDailyUsage findOrCreateUsageForUpdate(User user) {
        LocalDate date=LocalDate.now(clock);
        usageRepository.ensureDailyRow(user.getId(), date);
        return usageRepository.findForUpdate(user.getId(), date).orElseThrow();
    }

    private void releaseExpired(LocalDateTime now) {
        reservationRepository.releaseExpired(now);
    }

    private int activeReservations(User user, LocalDateTime now) {
        return Math.toIntExact(reservationRepository.countActive(
                user.getId(), LocalDate.now(clock), now));
    }

    private AiAssistantEntitlementResponse response(User user, AiAssistantAccess access, LocalDateTime now) {
        releaseExpired(now);
        AiAssistantDailyUsage usage=usageRepository
                .findByUserIdAndUsageDate(user.getId(), LocalDate.now(clock)).orElse(null);
        int used=usage == null ? 0 : usage.getSuccessfulQuestions();
        int reserved=activeReservations(user, now);
        int out=usage == null ? 0 : usage.getOutOfScopeAttempts();
        BusinessAccount business=businessAccount(user);
        int limit=dailyLimit(user);
        if (business != null) {
            limit=10;
            used=businessUsed(business);
            reserved=businessReservations(business, now);
        }
        int remaining=Math.max(0, limit-used-reserved);
        return new AiAssistantEntitlementResponse(
                assistantStatus(user, access, now), hasAssistantAccess(user, access, now) && remaining > 0,
                limit, used, remaining, out, access.getTrialExpiresAt(),
                access.getSubscriptionExpiresAt(), access.getLockedUntil());
    }
}
