package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.client.AiAssistantClient;
import com.gorkem.vehicle_inspector.dto.request.AiAssistantChatRequest;
import com.gorkem.vehicle_inspector.dto.response.*;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.UUID;
import java.util.Objects;
import java.util.Map;
import java.util.LinkedHashMap;

@Service
public class AiAssistantChatService {
    @org.springframework.beans.factory.annotation.Autowired
    private CreditWalletService credits;
    @org.springframework.beans.factory.annotation.Autowired
    private BusinessContextService businessContext;
    private final com.fasterxml.jackson.databind.ObjectMapper creditJson=new com.fasterxml.jackson.databind.ObjectMapper();
    private final AiAssistantClient aiClient;
    private final AiAssistantEntitlementService entitlement;
    private final AiAssistantToolContextService contextService;
    private final AiAssistantGenerationService generation;

    public AiAssistantChatService(AiAssistantClient aiClient, AiAssistantEntitlementService entitlement,
            AiAssistantToolContextService contextService, AiAssistantGenerationService generation) {
        this.aiClient=aiClient; this.entitlement=entitlement; this.contextService=contextService;
        this.generation=generation;
    }

    public AiAssistantChatResponse chat(AiAssistantChatRequest request, String email) {
        if (credits==null) return answer(request,email,false);
        var user=businessContext.requireUser(email);
        // Older clients remain subject to credit enforcement, even without an idempotency key.
        String key="question:"+(request.requestId()==null?UUID.randomUUID():request.requestId());
        String hash;
        try {
            byte[] payload=creditJson.writeValueAsBytes(java.util.Arrays.asList(request.question(),request.vehicleId(),request.history()));
            hash=java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(payload));
        } catch (Exception e) { throw new IllegalStateException("İstek doğrulanamadı.",e); }
        var reservation=credits.reserve(user,businessContext.isBusinessWorkspace(user),"ASSISTANT",key,hash);
        if (reservation.completed()) {
            try { return creditJson.readValue(credits.response(user,reservation.token()),AiAssistantChatResponse.class); }
            catch (Exception e) { throw new IllegalStateException("Önceki yanıt alınamadı; tekrar kredi düşülmedi.",e); }
        }
        boolean completed=false;
        try {
            if ("LOCKED".equals(entitlement.status(email).status().name()))
                throw new IllegalStateException("AI Asistan erişiminiz geçici olarak kilitli.");
            AiAssistantChatResponse result=answer(request,email,true);
            if (result.quotaConsumed()) {
                try { credits.completeWithResponse(user,reservation.token(),creditJson.writeValueAsString(result)); }
                catch (com.fasterxml.jackson.core.JsonProcessingException e) { throw new IllegalStateException("Yanıt kaydedilemedi.",e); }
                completed=true;
            }
            if (!completed) {
                credits.release(user,reservation.token());
                result=new AiAssistantChatResponse(result.intent(),result.answer(),false,
                        entitlement.status(email).remainingToday(),result.toolsUsed(),result.sources());
            }
            return result;
        } finally { if (!completed) credits.release(user,reservation.token()); }
    }

    private AiAssistantChatResponse answer(AiAssistantChatRequest request,String email,boolean creditMode) {
        if (!creditMode) entitlement.assertCanAsk(email);
        List<Map<String, String>> plannerHistory = request.history() == null ? List.of()
                : request.history().stream()
                    .map(item -> Map.of("role", item.role(), "content", item.content()))
                    .toList();
        Map<String, Object> vehicleContext = null;
        if (request.vehicleId() != null) {
            var vehicle = contextService.getVehicle(request.vehicleId(), email);
            vehicleContext = new LinkedHashMap<>();
            vehicleContext.put("brand", vehicle.brand());
            vehicleContext.put("model", vehicle.model());
            vehicleContext.put("modelYear", vehicle.modelYear());
        }
        AiAssistantPlanResponse plan=aiClient.plan(request.question(), plannerHistory, vehicleContext);

        validateSourcePlan(plan);

        if (!plan.inScope()) {
            entitlement.recordOutOfScope(email);
            var status=entitlement.status(email);
            return response(plan, "Bu konuda yardımcı olamıyorum. EksperSiz AI Asistan araç, bakım, muayene, güvenlik ve kayıtlı araç bilgilerinizle ilgili sorular için tasarlandı.",
                    false, status.remainingToday(), List.of());
        }

        if (plan.clarificationNeeded()) {
            var status = entitlement.status(email);
            String message = plan.clarificationMessage();
            if (message == null || message.isBlank()) {
                message = "Bu soruyu doğru yanıtlayabilmem için lütfen biraz daha spesifik bilgi paylaşın.";
            }
            return response(plan, message, false, status.remainingToday(), List.of());
        }

        if (plan.useRag() && (!plan.evidenceSufficient()
                || plan.context() == null || plan.context().isEmpty())) {
            var status=entitlement.status(email);
            return response(plan, "Bu soru için yeterince güçlü ve doğrulanmış bir kaynak bulamadım. Yanlış bilgi vermemek için tahminde bulunmayacağım.",
                    false, status.remainingToday(), List.of());
        }

        if (plan.toolName()!=null && request.vehicleId()==null && !"getMyVehicles".equals(plan.toolName())) {
            return response(plan, "Bu soruyu yanıtlamak için önce bir araç seçmelisiniz.", false,
                    entitlement.status(email).remainingToday(), List.of());
        }

        String toolContext=null;
        List<String> usedTools=List.of();
        if (plan.toolName()!=null) {
            toolContext=contextService.build(plan.toolName(), request.vehicleId(), email);
            usedTools=List.of(plan.toolName());
        }

        UUID reservationToken=creditMode?null:entitlement.reserveQuestion(email);
        boolean completed=false;
        try {
            String answer=generation.generate(
                    request.question(), plan, toolContext, request.history(), vehicleContext);
            if (!creditMode) entitlement.completeReservedQuestion(email, reservationToken);
            completed=true;
            var status=entitlement.status(email);
            return response(plan, answer, true, status.remainingToday(), usedTools);
        } finally {
            if (!completed && !creditMode) entitlement.releaseReservedQuestion(email, reservationToken);
        }
    }

    private void validateSourcePlan(AiAssistantPlanResponse plan) {
        if (!plan.inScope()) {
            if (plan.useRag() || plan.toolName() != null || !"NONE".equals(plan.knowledgeSource())) {
                throw new IllegalStateException("Invalid out-of-scope assistant plan");
            }
            return;
        }
        boolean valid = switch (plan.knowledgeSource()) {
            case "APP_KNOWLEDGE" -> plan.useRag() && plan.toolName() == null;
            case "PUBLIC_WEB" -> !plan.useRag() && plan.toolName() == null;
            case "USER_DATA" -> !plan.useRag() && plan.toolName() != null && java.util.Set.of(
                    "getMyVehicles", "getUpcomingReminders", "getDamageHistory").contains(plan.toolName());
            default -> false;
        };
        if (!valid) throw new IllegalStateException("Invalid assistant source/tool combination");
    }

    private AiAssistantChatResponse response(AiAssistantPlanResponse plan, String answer,
            boolean consumed, int remaining, List<String> toolsUsed) {
        var sources = plan.context() == null ? List.<AiAssistantChatResponse.Source>of()
                : plan.context().stream()
                    .filter(item -> item.sourceName() != null && !item.sourceName().isBlank())
                    .map(item -> new AiAssistantChatResponse.Source(item.sourceName(), item.sourceUrl()))
                    .filter(Objects::nonNull)
                    .distinct()
                    .toList();
        return new AiAssistantChatResponse(plan.intent(), answer, consumed, remaining, toolsUsed, sources);
    }

}
