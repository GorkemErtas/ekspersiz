package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.request.AcceptBusinessInvitationRequest;
import com.gorkem.vehicle_inspector.dto.request.CreateBusinessInvitationRequest;
import com.gorkem.vehicle_inspector.service.BusinessInvitationService;
import com.gorkem.vehicle_inspector.security.RequestRateLimiter;
import static com.gorkem.vehicle_inspector.security.RequestRateLimiter.Action.*;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/business-invitations")
public class BusinessInvitationController {

    private final BusinessInvitationService businessInvitationService;
    private final RequestRateLimiter rateLimiter;

    public BusinessInvitationController(
            BusinessInvitationService businessInvitationService,
            RequestRateLimiter rateLimiter
    ) {
        this.businessInvitationService =
                businessInvitationService;
        this.rateLimiter = rateLimiter;
    }

    @PostMapping
    public ResponseEntity<Void> invite(
            @Valid @RequestBody
            CreateBusinessInvitationRequest request,
            Authentication authentication
    ) {
        rateLimiter.check(INVITATION_SEND, authentication.getName());
        businessInvitationService.invite(
                authentication.getName(),
                request
        );

        return ResponseEntity.noContent().build();
    }

    @PostMapping("/accept")
    public ResponseEntity<Void> accept(
            @Valid @RequestBody
            AcceptBusinessInvitationRequest request,
            Authentication authentication
    ) {
        rateLimiter.check(INVITATION_CHECK, authentication.getName());
        businessInvitationService.accept(
                authentication.getName(),
                request.code()
        );

        return ResponseEntity.noContent().build();
    }
}
