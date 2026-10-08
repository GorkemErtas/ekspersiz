package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.AiAssistantEntitlementResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.UUID;

@Service
public class AiAssistantEntitlementService {
    public static final int DAILY_LIMIT = 3;
    public static final int OUT_OF_SCOPE_LOCK_THRESHOLD = 3;
    private final Duration reservationTtl;
    private final SubscriptionService subscriptions;

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
            @Value("${application.ai-assistant.usage-zone:Europe/Istanbul}") String usageZone,
            @Value("${application.ai-assistant.reservation-ttl:PT5M}") Duration reservationTtl) {
        this(accessRepository, usageRepository, reservationRepository,
                businessContext, Clock.system(ZoneId.of(usageZone)), reservationTtl);
        this.subscriptions = subscriptions;
    }

    AiAssistantEntitlementService(AiAssistantAccessRepository accessRepository,
            AiAssistantDailyUsageRepository usageRepository,
            AiAssistantQuotaReservationRepository reservationRepository,
            BusinessContextService businessContext, Clock clock, Duration reservationTtl) {
        if (reservationTtl == null || reservationTtl.isZero() || reservationTtl.isNegative())
            throw new IllegalArgumentException("AI assistant reservation TTL must be positive.");
        this.accessRepository=accessRepository; this.usageRepository=usageRepository;
        this.reservationRepository=reservationRepository;
        this.businessContext=businessContext; this.clock=clock;
        this.reservationTtl=reservationTtl;
        this.subscriptions=null;
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
        AiAssistantDailyUsage usage=findOrCreateUsageForUpdate(user);
        releaseExpired(now);
        if (usage.getSuccessfulQuestions() + activeReservations(user, now) >= dailyLimit(user))
            throw new IllegalStateException("Bugünkü AI Asistan soru hakkınızı kullandınız.");
    }

    @Transactional
    public UUID reserveQuestion(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        assertAccess(user, now);
        AiAssistantDailyUsage usage=findOrCreateUsageForUpdate(user);
        releaseExpired(now);
        if (usage.getSuccessfulQuestions() + activeReservations(user, now) >= dailyLimit(user))
            throw new IllegalStateException("Günlük AI Asistan kotası doldu.");
        UUID token=UUID.randomUUID();
        reservationRepository.save(new AiAssistantQuotaReservation(
                token, user, LocalDate.now(clock), now, now.plus(reservationTtl)));
        return token;
    }

    @Transactional
    public void completeReservedQuestion(String email, UUID token) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantDailyUsage usage=findOrCreateUsageForUpdate(user);
        AiAssistantQuotaReservation reservation=reservationRepository
                .findOwnedForUpdate(token, user.getId())
                .orElseThrow(() -> new IllegalStateException("AI quota reservation not found."));
        reservation.complete(now);
        usage.recordSuccessful(now);
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
                .orElseThrow(() -> new IllegalStateException("AI Asistan etkin değil."));
        if (!access.canAsk(now))
            throw new IllegalStateException("AI Asistan erişiminiz aktif değil.");
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
        int remaining=Math.max(0, dailyLimit(user)-used-reserved);
        return new AiAssistantEntitlementResponse(
                access.getStatus(), access.canAsk(now) && remaining > 0,
                dailyLimit(user), used, remaining, out, access.getTrialExpiresAt(),
                access.getSubscriptionExpiresAt(), access.getLockedUntil());
    }
}
