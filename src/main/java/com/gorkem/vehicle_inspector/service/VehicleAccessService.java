package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VehicleAccessService {
    private final VehicleRepository vehicles;
    private final BusinessContextService businessContext;

    public VehicleAccessService(VehicleRepository vehicles, BusinessContextService businessContext) {
        this.vehicles = vehicles;
        this.businessContext = businessContext;
    }

    @Transactional(readOnly = true)
    public Vehicle requireActiveVehicle(Long vehicleId, User user) {
        Vehicle vehicle = find(vehicleId, user, false);
        if (vehicle.isArchived()) throw notFound(vehicleId);
        return vehicle;
    }

    @Transactional(readOnly = true)
    public Vehicle requireVehicleIncludingArchived(Long vehicleId, User user) {
        return find(vehicleId, user, true);
    }

    private Vehicle find(Long vehicleId, User user, boolean includeArchived) {
        if (businessContext.findMembership(user).isPresent()) {
            var business = businessContext.requireBusinessAccount(user);
            return (includeArchived
                    ? vehicles.findByIdAndBusinessAccountId(vehicleId, business.getId())
                    : vehicles.findByIdAndBusinessAccountIdAndArchivedFalse(vehicleId, business.getId()))
                    .orElseThrow(() -> notFound(vehicleId));
        }

        return (includeArchived
                ? vehicles.findByIdAndUserId(vehicleId, user.getId())
                : vehicles.findByIdAndUserIdAndArchivedFalse(vehicleId, user.getId()))
                .orElseThrow(() -> notFound(vehicleId));
    }

    private ResourceNotFoundException notFound(Long id) {
        return new ResourceNotFoundException("Araç bulunamadı. ID: " + id);
    }
}
