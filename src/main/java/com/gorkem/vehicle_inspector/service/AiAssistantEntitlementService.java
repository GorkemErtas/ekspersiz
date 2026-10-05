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
    private final AiAssistantAccessRepository accessRepository;
    private final AiAssistantDailyUsageRepository usageRepository;
    private final BusinessContextService businessContext;
    private final Clock clock;

    public AiAssistantEntitlementService(AiAssistantAccessRepository accessRepository,
            AiAssistantDailyUsageRepository usageRepository, BusinessContextService businessContext) {
        this(accessRepository, usageRepository, businessContext, Clock.systemDefaultZone());
    }
    AiAssistantEntitlementService(AiAssistantAccessRepository accessRepository,
            AiAssistantDailyUsageRepository usageRepository, BusinessContextService businessContext, Clock clock) {
        this.accessRepository=accessRepository; this.usageRepository=usageRepository; this.businessContext=businessContext; this.clock=clock;
    }

    @Transactional
    public AiAssistantEntitlementResponse startTrial(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantAccess access=accessRepository.findByUserId(user.getId()).orElseGet(() -> new AiAssistantAccess(user, now));
        access.startTrial(now); accessRepository.save(access); return response(user, access, now);
    }

    @Transactional
    public AiAssistantEntitlementResponse status(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantAccess access=accessRepository.findByUserId(user.getId()).orElseGet(() -> accessRepository.save(new AiAssistantAccess(user, now)));
        access.refresh(now); return response(user, access, now);
    }

    @Transactional
    public void assertCanAsk(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantAccess access=accessRepository.findByUserId(user.getId()).orElseThrow(() -> new IllegalStateException("AI Asistan etkin değil."));
        if (!access.canAsk(now)) throw new IllegalStateException("AI Asistan erişiminiz aktif değil.");
        AiAssistantDailyUsage usage=findOrCreateUsage(user, now);
        if (usage.getSuccessfulQuestions() >= DAILY_LIMIT) throw new IllegalStateException("Bugünkü 3 AI Asistan soru hakkınızı kullandınız.");
    }

    @Transactional
    public void recordSuccessfulAnswer(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantDailyUsage usage=findOrCreateUsage(user, now);
        if (usage.getSuccessfulQuestions() >= DAILY_LIMIT) throw new IllegalStateException("Günlük AI Asistan kotası doldu.");
        usage.recordSuccess(now);
    }

    @Transactional
    public void recordOutOfScope(String email) {
        User user=businessContext.requireUser(email); LocalDateTime now=LocalDateTime.now(clock);
        AiAssistantDailyUsage usage=findOrCreateUsage(user, now); usage.recordOutOfScope(now);
        if (usage.getOutOfScopeAttempts() >= OUT_OF_SCOPE_LOCK_THRESHOLD) {
            AiAssistantAccess access=accessRepository.findByUserId(user.getId()).orElseThrow();
            access.lockUntil(now.plusHours(24), now);
        }
    }

    private AiAssistantDailyUsage findOrCreateUsage(User user, LocalDateTime now) {
        LocalDate date=LocalDate.now(clock);
        return usageRepository.findForUpdate(user.getId(), date).orElseGet(() -> usageRepository.save(new AiAssistantDailyUsage(user, date, now)));
    }
    private AiAssistantEntitlementResponse response(User user, AiAssistantAccess access, LocalDateTime now) {
        AiAssistantDailyUsage usage=usageRepository.findForUpdate(user.getId(), LocalDate.now(clock)).orElse(null);
        int used=usage == null ? 0 : usage.getSuccessfulQuestions(); int out=usage == null ? 0 : usage.getOutOfScopeAttempts();
        return new AiAssistantEntitlementResponse(access.getStatus(), access.canAsk(now) && used < DAILY_LIMIT,
                DAILY_LIMIT, used, Math.max(0, DAILY_LIMIT-used), out, access.getTrialExpiresAt(), access.getSubscriptionExpiresAt(), access.getLockedUntil());
    }
}
