package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.AiAssistantEntitlementResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;

@Service
public class AiAssistantEntitlementService {
    public static final int DAILY_LIMIT = 3;
    public static final int OUT_OF_SCOPE_LOCK_THRESHOLD = 3;
    private static final ZoneId USAGE_ZONE = ZoneId.of("Europe/Istanbul");

    private final AiAssistantAccessRepository accessRepository;
    private final AiAssistantDailyUsageRepository usageRepository;
    private final BusinessContextService businessContext;
    private final Clock clock;

    public AiAssistantEntitlementService(AiAssistantAccessRepository accessRepository,
            AiAssistantDailyUsageRepository usageRepository, BusinessContextService businessContext) {
        this(accessRepository, usageRepository, businessContext, Clock.system(USAGE_ZONE));
    }

    AiAssistantEntitlementService(AiAssistantAccessRepository accessRepository,
            AiAssistantDailyUsageRepository usageRepository, BusinessContextService businessContext, Clock clock) {
        this.accessRepository=accessRepository; this.usageRepository=usageRepository;
        this.businessContext=businessContext; this.clock=clock;
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
        AiAssistantAccess access=accessRepository.findByUserId(user.getId())
                .orElseThrow(() -> new IllegalStateException("AI Asistan etkin değil."));
        if (!access.canAsk(now)) throw new IllegalStateException("AI Asistan erişiminiz aktif değil.");
        AiAssistantDailyUsage usage=findOrCreateUsageForUpdate(user);
        if (usage.getSuccessfulQuestions() + usage.getReservedQuestions() >= DAILY_LIMIT)
            throw new IllegalStateException("Bugünkü 3 AI Asistan soru hakkınızı kullandınız.");
    }

    @Transactional
    public void reserveQuestion(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantAccess access=accessRepository.findByUserId(user.getId())
                .orElseThrow(() -> new IllegalStateException("AI Asistan etkin değil."));
        if (!access.canAsk(now)) throw new IllegalStateException("AI Asistan erişiminiz aktif değil.");
        AiAssistantDailyUsage usage=findOrCreateUsageForUpdate(user);
        if (usage.getSuccessfulQuestions() + usage.getReservedQuestions() >= DAILY_LIMIT)
            throw new IllegalStateException("Günlük AI Asistan kotası doldu.");
        usage.reserve(now);
    }

    @Transactional
    public void completeReservedQuestion(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        findOrCreateUsageForUpdate(user).completeReservation(now);
    }

    @Transactional
    public void releaseReservedQuestion(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        findOrCreateUsageForUpdate(user).releaseReservation(now);
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

    private AiAssistantDailyUsage findOrCreateUsageForUpdate(User user) {
        LocalDate date=LocalDate.now(clock);
        usageRepository.ensureDailyRow(user.getId(), date);
        return usageRepository.findForUpdate(user.getId(), date).orElseThrow();
    }

    private AiAssistantEntitlementResponse response(User user, AiAssistantAccess access, LocalDateTime now) {
        AiAssistantDailyUsage usage=usageRepository
                .findByUserIdAndUsageDate(user.getId(), LocalDate.now(clock)).orElse(null);
        int used=usage == null ? 0 : usage.getSuccessfulQuestions();
        int reserved=usage == null ? 0 : usage.getReservedQuestions();
        int out=usage == null ? 0 : usage.getOutOfScopeAttempts();
        int remaining=Math.max(0, DAILY_LIMIT-used-reserved);
        return new AiAssistantEntitlementResponse(
                access.getStatus(), access.canAsk(now) && remaining > 0,
                DAILY_LIMIT, used, remaining, out, access.getTrialExpiresAt(),
                access.getSubscriptionExpiresAt(), access.getLockedUntil());
    }
}
