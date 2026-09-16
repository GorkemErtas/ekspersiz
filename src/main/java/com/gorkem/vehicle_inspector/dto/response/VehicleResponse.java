package com.gorkem.vehicle_inspector.dto.response;

import java.time.LocalDateTime;

public class VehicleResponse {

    private Long id;
    private String plate;
    private String brand;
    private String model;
    private Integer modelYear;
    private Integer mileage;
    private boolean primaryVehicle;
    private String notes;
    private LocalDateTime createdAt;

    public VehicleResponse(
            Long id,
            String plate,
            String brand,
            String model,
            Integer modelYear,
            Integer mileage,
            boolean primaryVehicle,
            String notes,
            LocalDateTime createdAt
    ) {
        this.id = id;
        this.plate = plate;
        this.brand = brand;
        this.model = model;
        this.modelYear = modelYear;
        this.mileage = mileage;
        this.primaryVehicle = primaryVehicle;
        this.notes = notes;
        this.createdAt = createdAt;
    }

    public Long getId() { return id; }
    public String getPlate() { return plate; }
    public String getBrand() { return brand; }
    public String getModel() { return model; }
    public Integer getModelYear() { return modelYear; }
    public Integer getMileage() { return mileage; }
    public boolean isPrimaryVehicle() { return primaryVehicle; }
    public String getNotes() { return notes; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
