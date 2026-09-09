package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.response.DamageInspectionResponse;
import com.gorkem.vehicle_inspector.service.DamageInspectionService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.CacheControl;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

@RestController
@RequestMapping("/api/v1/inspections")
public class DamageInspectionController {

    private final DamageInspectionService inspectionService;

    public DamageInspectionController(
            DamageInspectionService inspectionService
    ) {
        this.inspectionService = inspectionService;
    }

    @PostMapping
    public ResponseEntity<DamageInspectionResponse>
    createInspection(
            @RequestParam Long vehicleId,
            @RequestParam String city,
            Authentication authentication
    ) {
        DamageInspectionResponse response =
                inspectionService.createInspection(
                        vehicleId,
                        city,
                        authentication.getName()
                );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }

    @GetMapping
    public ResponseEntity<List<DamageInspectionResponse>>
    getMyInspections(Authentication authentication) {

        return ResponseEntity.ok(
                inspectionService.getMyInspections(
                        authentication.getName()
                )
        );
    }

    @GetMapping("/{inspectionId}/image")
    public ResponseEntity<Resource>
    getInspectionImage(
            @PathVariable Long inspectionId,
            Authentication authentication
    ) {
        Path imagePath =
                inspectionService.getInspectionImage(
                        inspectionId,
                        authentication.getName()
                );

        try {
            Resource resource =
                    new UrlResource(
                            imagePath.toUri()
                    );

            if (!resource.exists()
                    || !resource.isReadable()) {

                throw new IllegalStateException(
                        "Fotoğraf okunamıyor."
                );
            }

            String contentType =
                    Files.probeContentType(
                            imagePath
                    );

            if (contentType == null) {
                contentType =
                        MediaType.APPLICATION_OCTET_STREAM_VALUE;
            }

            return ResponseEntity.ok()
                    .cacheControl(
                            CacheControl.noStore()
                    )
                    .contentType(
                            MediaType.parseMediaType(
                                    contentType
                            )
                    )
                    .body(resource);

        } catch (MalformedURLException exception) {
            throw new IllegalStateException(
                    "Fotoğraf yolu geçersiz.",
                    exception
            );

        } catch (IOException exception) {
            throw new IllegalStateException(
                    "Fotoğraf tipi belirlenemedi.",
                    exception
            );
        }
    }

    @GetMapping("/{inspectionId}")
    public ResponseEntity<DamageInspectionResponse>
    getMyInspectionById(
            @PathVariable Long inspectionId,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                inspectionService.getMyInspectionById(
                        inspectionId,
                        authentication.getName()
                )
        );
    }

    @PostMapping(
            value = "/{inspectionId}/image",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ResponseEntity<DamageInspectionResponse>
    uploadInspectionImage(
            @PathVariable Long inspectionId,
            @RequestPart("image") MultipartFile image,
            Authentication authentication
    ) {
        DamageInspectionResponse response =
                inspectionService.uploadInspectionImage(
                        inspectionId,
                        image,
                        authentication.getName()
                );

        return ResponseEntity.ok(response);
    }

    @PostMapping("/{inspectionId}/analyze")
    public ResponseEntity<DamageInspectionResponse>
    analyzeInspection(
            @PathVariable Long inspectionId,
            Authentication authentication
    ) {
        DamageInspectionResponse response =
                inspectionService.analyzeInspection(
                        inspectionId,
                        authentication.getName()
                );

        return ResponseEntity.ok(response);
    }

    @PostMapping("/{inspectionId}/report")
    public ResponseEntity<DamageInspectionResponse>
    regenerateReport(
            @PathVariable Long inspectionId,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                inspectionService.regenerateReport(
                        inspectionId,
                        authentication.getName()
                )
        );
    }
}