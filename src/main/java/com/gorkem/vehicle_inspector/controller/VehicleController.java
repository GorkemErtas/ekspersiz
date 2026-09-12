package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.request.CreateVehicleRequest;
import com.gorkem.vehicle_inspector.dto.request.UpdateVehicleRequest;
import com.gorkem.vehicle_inspector.dto.response.VehicleResponse;
import com.gorkem.vehicle_inspector.service.VehicleService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/vehicles")
public class VehicleController {

    private final VehicleService vehicleService;

    public VehicleController(VehicleService vehicleService) {
        this.vehicleService = vehicleService;
    }

    @PostMapping
    public ResponseEntity<VehicleResponse> createVehicle(
            @Valid @RequestBody CreateVehicleRequest request,
            Authentication authentication
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(vehicleService.createVehicle(request, authentication.getName()));
    }

    @GetMapping
    public ResponseEntity<List<VehicleResponse>> getMyVehicles(
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                vehicleService.getMyVehicles(authentication.getName())
        );
    }

    @GetMapping("/{id}")
    public ResponseEntity<VehicleResponse> getMyVehicleById(
            @PathVariable Long id,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                vehicleService.getMyVehicleById(id, authentication.getName())
        );
    }

    @PutMapping("/{id}")
    public ResponseEntity<VehicleResponse> updateVehicle(
            @PathVariable Long id,
            @Valid @RequestBody UpdateVehicleRequest request,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                vehicleService.updateVehicle(id, request, authentication.getName())
        );
    }

    @PutMapping("/{id}/primary")
    public ResponseEntity<VehicleResponse> setPrimaryVehicle(
            @PathVariable Long id,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                vehicleService.setPrimaryVehicle(id, authentication.getName())
        );
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteVehicle(
            @PathVariable Long id,
            Authentication authentication
    ) {
        vehicleService.deleteVehicle(id, authentication.getName());
        return ResponseEntity.noContent().build();
    }
}
