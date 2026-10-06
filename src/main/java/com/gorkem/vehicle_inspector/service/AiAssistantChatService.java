package com.gorkem.vehicle_inspector.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.client.AiAssistantClient;
import com.gorkem.vehicle_inspector.dto.request.AiAssistantChatRequest;
import com.gorkem.vehicle_inspector.dto.response.*;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class AiAssistantChatService {
    private final AiAssistantClient aiClient;
    private final AiAssistantEntitlementService entitlement;
    private final AiAssistantToolService tools;
    private final AiAssistantGenerationService generation;
    private final ObjectMapper objectMapper;

    public AiAssistantChatService(AiAssistantClient aiClient, AiAssistantEntitlementService entitlement,
            AiAssistantToolService tools, AiAssistantGenerationService generation, ObjectMapper objectMapper) {
        this.aiClient=aiClient; this.entitlement=entitlement; this.tools=tools;
        this.generation=generation; this.objectMapper=objectMapper;
    }

    public AiAssistantChatResponse chat(AiAssistantChatRequest request, String email) {
        entitlement.assertCanAsk(email);
        AiAssistantPlanResponse plan=aiClient.plan(request.question());

        if (!plan.inScope()) {
            entitlement.recordOutOfScope(email);
            var status=entitlement.status(email);
            return response(plan, "Bu konuda yardımcı olamıyorum. EksperSiz AI Asistan araç, bakım, muayene, güvenlik ve kayıtlı araç bilgilerinizle ilgili sorular için tasarlandı.",
                    false, status.remainingToday(), List.of());
        }

        if (plan.useRag() && (plan.context() == null || plan.context().isEmpty())) {
            var status=entitlement.status(email);
            return response(plan, "Bu soru için doğrulanmış bilgi tabanımda yeterli kaynak bulamadım. Yanlış bilgi vermemek için tahminde bulunmayacağım.",
                    false, status.remainingToday(), List.of());
        }

        if (plan.toolName()!=null && request.vehicleId()==null && !"getMyVehicles".equals(plan.toolName())) {
            return response(plan, "Bu soruyu yanıtlamak için önce bir araç seçmelisiniz.", false,
                    entitlement.status(email).remainingToday(), List.of());
        }

        String toolContext=null;
        List<String> usedTools=List.of();
        if (plan.toolName()!=null) {
            toolContext=executeTool(plan.toolName(), request.vehicleId(), email);
            usedTools=List.of(plan.toolName());
        }

        entitlement.reserveQuestion(email);
        boolean completed=false;
        try {
            String answer=generation.generate(request.question(), plan, toolContext);
            entitlement.completeReservedQuestion(email);
            completed=true;
            var status=entitlement.status(email);
            return response(plan, answer, true, status.remainingToday(), usedTools);
        } finally {
            if (!completed) entitlement.releaseReservedQuestion(email);
        }
    }

    private AiAssistantChatResponse response(AiAssistantPlanResponse plan, String answer,
            boolean consumed, int remaining, List<String> toolsUsed) {
        return new AiAssistantChatResponse(plan.intent(), answer, consumed, remaining, toolsUsed);
    }

    private String executeTool(String toolName, Long vehicleId, String email) {
        Object value=switch (toolName) {
            case "getDamageHistory" -> tools.getDamageHistory(vehicleId, email);
            case "getUpcomingReminders" -> tools.getUpcomingReminders(vehicleId, email);
            case "getMyVehicles" -> tools.getMyVehicles(email);
            default -> throw new IllegalArgumentException("Desteklenmeyen AI tool: " + toolName);
        };
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException exc) {
            throw new IllegalStateException("AI tool context serialize edilemedi.", exc);
        }
    }
}
