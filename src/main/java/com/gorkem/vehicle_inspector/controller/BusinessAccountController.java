package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.request.CreateBusinessAccountRequest;
import com.gorkem.vehicle_inspector.dto.response.BusinessAccountResponse;
import com.gorkem.vehicle_inspector.service.BusinessAccountService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/business-accounts")
public class BusinessAccountController {

    private final BusinessAccountService businessAccountService;

    public BusinessAccountController(
            BusinessAccountService businessAccountService
    ) {
        this.businessAccountService = businessAccountService;
    }

    @PostMapping
    public ResponseEntity<BusinessAccountResponse> create(
            @Valid @RequestBody CreateBusinessAccountRequest request,
            Authentication authentication
    ) {
        BusinessAccountResponse response =
                businessAccountService.create(
                        authentication.getName(),
                        request
                );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }
}