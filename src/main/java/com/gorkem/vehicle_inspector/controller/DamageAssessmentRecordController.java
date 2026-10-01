package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.request.DamageAssessmentRecordRequest;
import com.gorkem.vehicle_inspector.dto.response.DamageAssessmentRecordResponse;
import com.gorkem.vehicle_inspector.service.DamageAssessmentRecordService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/inspections/{inspectionId}/damage-record")
public class DamageAssessmentRecordController {

    private final DamageAssessmentRecordService service;

    public DamageAssessmentRecordController(
            DamageAssessmentRecordService service
    ) {
        this.service = service;
    }

    @GetMapping
    public DamageAssessmentRecordResponse get(
            @PathVariable Long inspectionId,
            Authentication authentication
    ) {
        return service.get(inspectionId, authentication.getName());
    }

    @PostMapping
    public ResponseEntity<DamageAssessmentRecordResponse> create(
            @PathVariable Long inspectionId,
            @Valid @RequestBody DamageAssessmentRecordRequest request,
            Authentication authentication
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(service.create(
                        inspectionId,
                        request,
                        authentication.getName()
                ));
    }

    @PutMapping
    public DamageAssessmentRecordResponse update(
            @PathVariable Long inspectionId,
            @Valid @RequestBody DamageAssessmentRecordRequest request,
            Authentication authentication
    ) {
        return service.update(
                inspectionId,
                request,
                authentication.getName()
        );
    }

    @PostMapping("/finalize")
    public DamageAssessmentRecordResponse finalizeRecord(
            @PathVariable Long inspectionId,
            Authentication authentication
    ) {
        return service.finalizeRecord(
                inspectionId,
                authentication.getName()
        );
    }
}
