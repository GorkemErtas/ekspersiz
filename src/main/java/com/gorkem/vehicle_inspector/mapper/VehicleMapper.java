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
        return new Vehicle(
                request.getPlate().trim().toUpperCase(),
                request.getBrand().trim(),
                request.getModel().trim(),
                request.getModelYear(),
                request.getMileage(),
                user
        );
    }

    public static Vehicle toEntity(
            CreateVehicleRequest request,
            BusinessAccount businessAccount
    ) {
        return new Vehicle(
                request.getPlate().trim().toUpperCase(),
                request.getBrand().trim(),
                request.getModel().trim(),
                request.getModelYear(),
                request.getMileage(),
                businessAccount
        );
    }

    public static VehicleResponse toResponse(Vehicle vehicle) {
        return new VehicleResponse(
                vehicle.getId(),
                vehicle.getPlate(),
                vehicle.getBrand(),
                vehicle.getModel(),
                vehicle.getModelYear(),
                vehicle.getMileage(),
                vehicle.isPrimaryVehicle()
        );
    }

    public static void updateEntity(Vehicle vehicle, UpdateVehicleRequest request) {
        vehicle.setPlate(request.getPlate().trim().toUpperCase());
        vehicle.setBrand(request.getBrand().trim());
        vehicle.setModel(request.getModel().trim());
        vehicle.setModelYear(request.getModelYear());
        vehicle.setMileage(request.getMileage());
    }
}
