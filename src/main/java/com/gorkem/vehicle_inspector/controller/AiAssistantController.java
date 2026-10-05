package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.dto.request.AiAssistantChatRequest;
import jakarta.validation.Valid;
import com.gorkem.vehicle_inspector.service.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/ai-assistant")
public class AiAssistantController {
    private final AiAssistantEntitlementService entitlement;
    private final AiAssistantToolService tools;
    private final AiAssistantChatService chat;
    public AiAssistantController(AiAssistantEntitlementService entitlement, AiAssistantToolService tools, AiAssistantChatService chat) {
        this.entitlement=entitlement; this.tools=tools; this.chat=chat;
    }
    @PostMapping("/chat")
    public AiAssistantChatResponse chat(@Valid @RequestBody AiAssistantChatRequest request, Authentication auth) { return chat.chat(request, auth.getName()); }
    @GetMapping("/entitlement")
    public AiAssistantEntitlementResponse entitlement(Authentication auth) { return entitlement.status(auth.getName()); }
    @PostMapping("/trial")
    public AiAssistantEntitlementResponse startTrial(Authentication auth) { return entitlement.startTrial(auth.getName()); }
    @GetMapping("/tools/vehicles")
    public List<AiAssistantVehicleToolResponse> vehicles(Authentication auth) { return tools.getMyVehicles(auth.getName()); }
    @GetMapping("/tools/vehicles/{vehicleId}")
    public AiAssistantVehicleToolResponse vehicle(@PathVariable Long vehicleId, Authentication auth) { return tools.getVehicle(vehicleId, auth.getName()); }
    @GetMapping("/tools/vehicles/{vehicleId}/reminders")
    public List<AiAssistantReminderToolResponse> reminders(@PathVariable Long vehicleId, Authentication auth) { return tools.getUpcomingReminders(vehicleId, auth.getName()); }
    @GetMapping("/tools/vehicles/{vehicleId}/damage-history")
    public List<AiAssistantDamageToolResponse> damageHistory(@PathVariable Long vehicleId, Authentication auth) { return tools.getDamageHistory(vehicleId, auth.getName()); }
}
