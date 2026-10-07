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
        entitlement.assertCanAsk(email);
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

        UUID reservationToken=entitlement.reserveQuestion(email);
        boolean completed=false;
        try {
            String answer=generation.generate(
                    request.question(), plan, toolContext, request.history(), vehicleContext);
            entitlement.completeReservedQuestion(email, reservationToken);
            completed=true;
            var status=entitlement.status(email);
            return response(plan, answer, true, status.remainingToday(), usedTools);
        } finally {
            if (!completed) entitlement.releaseReservedQuestion(email, reservationToken);
        }
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
