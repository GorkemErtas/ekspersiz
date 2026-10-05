package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.client.AiAssistantClient;
import com.gorkem.vehicle_inspector.dto.request.AiAssistantChatRequest;
import com.gorkem.vehicle_inspector.dto.response.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class AiAssistantChatService {
    private final AiAssistantClient aiClient;
    private final AiAssistantEntitlementService entitlement;
    private final AiAssistantToolService tools;
    private final AiAssistantGenerationService generation;

    public AiAssistantChatService(AiAssistantClient aiClient, AiAssistantEntitlementService entitlement, AiAssistantToolService tools, AiAssistantGenerationService generation) {
        this.aiClient=aiClient; this.entitlement=entitlement; this.tools=tools; this.generation=generation;
    }

    @Transactional
    public AiAssistantChatResponse chat(AiAssistantChatRequest request, String email) {
        entitlement.assertCanAsk(email);
        AiAssistantPlanResponse plan=aiClient.plan(request.question());
        if (!plan.inScope()) {
            entitlement.recordOutOfScope(email);
            var status=entitlement.status(email);
            return new AiAssistantChatResponse(plan.intent(),
                    "Bu konuda yardımcı olamıyorum. EksperSiz AI Asistan araç, bakım, muayene, güvenlik ve kayıtlı araç bilgilerinizle ilgili sorular için tasarlandı.",
                    false, status.remainingToday(), List.of());
        }

        String answer;
        String toolContext=null;
        List<String> usedTools=List.of();
        if (plan.toolName()!=null) {
            if (request.vehicleId()==null && !"getMyVehicles".equals(plan.toolName())) {
                return new AiAssistantChatResponse(plan.intent(), "Bu soruyu yanıtlamak için önce bir araç seçmelisiniz.", false,
                        entitlement.status(email).remainingToday(), List.of());
            }
            toolContext=executeTool(plan.toolName(), request.vehicleId(), email);
            usedTools=List.of(plan.toolName());
        }
        answer=generation.generate(request.question(), plan, toolContext);

        entitlement.recordSuccessfulAnswer(email);
        var status=entitlement.status(email);
        return new AiAssistantChatResponse(plan.intent(), answer, true, status.remainingToday(), usedTools);
    }

    private String executeTool(String toolName, Long vehicleId, String email) {
        return switch (toolName) {
            case "getDamageHistory" -> tools.getDamageHistory(vehicleId, email).toString();
            case "getUpcomingReminders" -> tools.getUpcomingReminders(vehicleId, email).toString();
            case "getMyVehicles" -> tools.getMyVehicles(email).toString();
            default -> throw new IllegalArgumentException("Desteklenmeyen AI tool: " + toolName);
        };
    }
}
