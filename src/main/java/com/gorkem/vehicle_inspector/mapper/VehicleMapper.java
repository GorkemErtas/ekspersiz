package com.gorkem.vehicle_inspector.mapper;

import com.gorkem.vehicle_inspector.dto.request.CreateVehicleRequest;
import com.gorkem.vehicle_inspector.dto.request.UpdateVehicleRequest;
import com.gorkem.vehicle_inspector.dto.response.VehicleResponse;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;

public final class VehicleMapper {

    private VehicleMapper() {
    }

    public static Vehicle toEntity(CreateVehicleRequest request, User user) {
        Vehicle vehicle = new Vehicle(
                request.getPlate().trim().toUpperCase(),
                request.getBrand().trim(),
                request.getModel().trim(),
                request.getModelYear(),
                request.getMileage(),
                user
        );
        applyTrackingProfile(vehicle, request.getVehicleCategory(), request.getConformityDate());
        return vehicle;
    }

    public static Vehicle toEntity(
            CreateVehicleRequest request,
            BusinessAccount businessAccount
    ) {
        Vehicle vehicle = new Vehicle(
                request.getPlate().trim().toUpperCase(),
                request.getBrand().trim(),
                request.getModel().trim(),
                request.getModelYear(),
                request.getMileage(),
                businessAccount
        );
        applyTrackingProfile(vehicle, request.getVehicleCategory(), request.getConformityDate());
        return vehicle;
    }

    public static VehicleResponse toResponse(Vehicle vehicle) {
        return new VehicleResponse(
                vehicle.getId(),
                vehicle.getPlate(),
                vehicle.getBrand(),
                vehicle.getModel(),
                vehicle.getModelYear(),
                vehicle.getMileage(),
                vehicle.getVehicleCategory(),
                vehicle.getConformityDate(),
                vehicle.isPrimaryVehicle(),
                vehicle.getNotes(),
                vehicle.getCreatedAt()
        );
    }

    public static void updateEntity(Vehicle vehicle, UpdateVehicleRequest request) {
        vehicle.setPlate(request.getPlate().trim().toUpperCase());
        vehicle.setBrand(request.getBrand().trim());
        vehicle.setModel(request.getModel().trim());
        vehicle.setModelYear(request.getModelYear());
        vehicle.setMileage(request.getMileage());
        if (request.getVehicleCategory() != null) {
            vehicle.setVehicleCategory(request.getVehicleCategory());
        }
        if (request.getConformityDate() != null) {
            vehicle.setConformityDate(request.getConformityDate());
        }
        if (request.getNotes() != null) {
            vehicle.setNotes(request.getNotes());
        }
    }

    private static void applyTrackingProfile(Vehicle vehicle,
                                             com.gorkem.vehicle_inspector.entity.VehicleCategory category,
                                             java.time.LocalDate conformityDate) {
        vehicle.setVehicleCategory(category);
        vehicle.setConformityDate(conformityDate);
    }
}
