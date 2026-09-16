package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.response.BusinessMemberResponse;
import com.gorkem.vehicle_inspector.service.BusinessMemberService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/business-members")
public class BusinessMemberController {

    private final BusinessMemberService businessMemberService;

    public BusinessMemberController(
            BusinessMemberService businessMemberService
    ) {
        this.businessMemberService = businessMemberService;
    }

    @GetMapping
    public ResponseEntity<List<BusinessMemberResponse>> getEmployees(
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                businessMemberService.getEmployees(authentication.getName())
        );
    }

    @DeleteMapping("/{membershipId}")
    public ResponseEntity<Void> removeEmployee(
            @PathVariable Long membershipId,
            Authentication authentication
    ) {
        businessMemberService.removeEmployee(
                authentication.getName(),
                membershipId
        );

        return ResponseEntity.noContent().build();
    }
}
