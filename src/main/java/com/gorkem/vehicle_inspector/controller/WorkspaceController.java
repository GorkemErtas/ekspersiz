package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.workspace.WorkspaceContext;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class WorkspaceController {
    private final BusinessContextService context;
    public WorkspaceController(BusinessContextService context) { this.context = context; }

    @GetMapping("/api/v1/workspace")
    public WorkspaceContext current(Authentication authentication) {
        return context.workspace(context.requireUser(authentication.getName()));
    }
}
