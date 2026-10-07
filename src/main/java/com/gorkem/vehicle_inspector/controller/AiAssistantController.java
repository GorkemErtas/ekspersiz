package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.request.AiAssistantChatRequest;
import com.gorkem.vehicle_inspector.dto.response.AiAssistantChatResponse;
import com.gorkem.vehicle_inspector.dto.response.AiAssistantEntitlementResponse;
import com.gorkem.vehicle_inspector.service.AiAssistantChatService;
import com.gorkem.vehicle_inspector.service.AiAssistantEntitlementService;
import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/ai-assistant")
public class AiAssistantController {
    private final AiAssistantEntitlementService entitlement;
    private final AiAssistantChatService chat;

    public AiAssistantController(AiAssistantEntitlementService entitlement,
                                 AiAssistantChatService chat) {
        this.entitlement = entitlement;
        this.chat = chat;
    }

    @PostMapping("/chat")
    public AiAssistantChatResponse chat(@Valid @RequestBody AiAssistantChatRequest request,
                                        Authentication authentication) {
        return chat.chat(request, authentication.getName());
    }

    @GetMapping("/entitlement")
    public AiAssistantEntitlementResponse entitlement(Authentication authentication) {
        return entitlement.status(authentication.getName());
    }

    @PostMapping("/trial")
    public AiAssistantEntitlementResponse startTrial(Authentication authentication) {
        return entitlement.startTrial(authentication.getName());
    }
}
