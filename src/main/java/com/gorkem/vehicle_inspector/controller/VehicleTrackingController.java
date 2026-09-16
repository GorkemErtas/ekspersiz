package com.gorkem.vehicle_inspector.controller;

import com.gorkem.vehicle_inspector.dto.request.MaintenanceRequest;
import com.gorkem.vehicle_inspector.dto.request.ReminderRequest;
import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.service.MaintenanceService;
import com.gorkem.vehicle_inspector.service.ReminderService;
import com.gorkem.vehicle_inspector.service.VehicleOverviewService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/vehicles/{vehicleId}")
public class VehicleTrackingController {
    private final MaintenanceService maintenance;
    private final ReminderService reminders;
    private final VehicleOverviewService overview;

    public VehicleTrackingController(MaintenanceService maintenance,
                                     ReminderService reminders,
                                     VehicleOverviewService overview) {
        this.maintenance = maintenance; this.reminders = reminders; this.overview = overview;
    }

    @GetMapping("/maintenance")
    public List<MaintenanceResponse> maintenance(@PathVariable Long vehicleId, Authentication auth) {
        return maintenance.list(vehicleId, auth.getName());
    }

    @PostMapping("/maintenance")
    public ResponseEntity<MaintenanceResponse> addMaintenance(@PathVariable Long vehicleId,
            @Valid @RequestBody MaintenanceRequest request, Authentication auth) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(maintenance.create(vehicleId, request, auth.getName()));
    }

    @PutMapping("/maintenance/{recordId}")
    public MaintenanceResponse updateMaintenance(@PathVariable Long vehicleId,
            @PathVariable Long recordId, @Valid @RequestBody MaintenanceRequest request,
            Authentication auth) {
        return maintenance.update(vehicleId, recordId, request, auth.getName());
    }

    @DeleteMapping("/maintenance/{recordId}")
    public ResponseEntity<Void> deleteMaintenance(@PathVariable Long vehicleId,
            @PathVariable Long recordId, Authentication auth) {
        maintenance.delete(vehicleId, recordId, auth.getName());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/reminders")
    public List<ReminderResponse> reminders(@PathVariable Long vehicleId, Authentication auth) {
        return reminders.list(vehicleId, auth.getName());
    }

    @PostMapping("/reminders")
    public ResponseEntity<ReminderResponse> addReminder(@PathVariable Long vehicleId,
            @Valid @RequestBody ReminderRequest request, Authentication auth) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(reminders.create(vehicleId, request, auth.getName()));
    }

    @PutMapping("/reminders/{reminderId}")
    public ReminderResponse updateReminder(@PathVariable Long vehicleId,
            @PathVariable Long reminderId, @Valid @RequestBody ReminderRequest request,
            Authentication auth) {
        return reminders.update(vehicleId, reminderId, request, auth.getName());
    }

    @PutMapping("/reminders/{reminderId}/completion")
    public ReminderResponse completeReminder(@PathVariable Long vehicleId,
            @PathVariable Long reminderId, @RequestParam boolean completed, Authentication auth) {
        return reminders.setCompleted(vehicleId, reminderId, completed, auth.getName());
    }

    @DeleteMapping("/reminders/{reminderId}")
    public ResponseEntity<Void> deleteReminder(@PathVariable Long vehicleId,
            @PathVariable Long reminderId, Authentication auth) {
        reminders.delete(vehicleId, reminderId, auth.getName());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/overview")
    public VehicleOverviewResponse overview(@PathVariable Long vehicleId, Authentication auth) {
        return overview.overview(vehicleId, auth.getName());
    }

    @GetMapping("/history")
    public List<VehicleHistoryItemResponse> history(@PathVariable Long vehicleId, Authentication auth) {
        return overview.history(vehicleId, auth.getName());
    }
}
