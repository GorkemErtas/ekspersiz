package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.DamageInspection;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class InspectionAccessService {

    private final DamageInspectionRepository inspectionRepository;
    private final BusinessContextService businessContextService;

    public InspectionAccessService(
            DamageInspectionRepository inspectionRepository,
            BusinessContextService businessContextService
    ) {
        this.inspectionRepository = inspectionRepository;
        this.businessContextService = businessContextService;
    }

    @Transactional(readOnly = true)
    public DamageInspection requireInspection(Long inspectionId, User user) {
        DamageInspection inspection = inspectionRepository.findById(inspectionId)
                .orElseThrow(() -> notFound(inspectionId));
        return validateAccess(inspection, user);
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public DamageInspection requireInspectionForUpdate(Long inspectionId, User user) {
        DamageInspection inspection = inspectionRepository.findByIdForUpdate(inspectionId)
                .orElseThrow(() -> notFound(inspectionId));
        return validateAccess(inspection, user);
    }

    private DamageInspection validateAccess(DamageInspection inspection, User user) {
        Vehicle vehicle = inspection.getVehicle();
        boolean accessible = businessContextService.findMembership(user)
                .map(member -> vehicle.getBusinessAccount() != null
                        && member.getBusinessAccount().getId()
                        .equals(vehicle.getBusinessAccount().getId()))
                .orElseGet(() -> vehicle.getBusinessAccount() == null
                        && vehicle.getUser() != null
                        && user.getId().equals(vehicle.getUser().getId()));

        if (!accessible) {
            throw notFound(inspection.getId());
        }
        return inspection;
    }

    private ResourceNotFoundException notFound(Long inspectionId) {
        return new ResourceNotFoundException("Hasar incelemesi bulunamadı. ID: " + inspectionId);
    }
}
