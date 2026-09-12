package com.gorkem.vehicle_inspector.dto.response;

public class VehicleResponse {

    private Long id;
    private String plate;
    private String brand;
    private String model;
    private Integer modelYear;
    private Integer mileage;
    private boolean primaryVehicle;

    public VehicleResponse(
            Long id,
            String plate,
            String brand,
            String model,
            Integer modelYear,
            Integer mileage,
            boolean primaryVehicle
    ) {
        this.id = id;
        this.plate = plate;
        this.brand = brand;
        this.model = model;
        this.modelYear = modelYear;
        this.mileage = mileage;
        this.primaryVehicle = primaryVehicle;
    }

    public Long getId() { return id; }
    public String getPlate() { return plate; }
    public String getBrand() { return brand; }
    public String getModel() { return model; }
    public Integer getModelYear() { return modelYear; }
    public Integer getMileage() { return mileage; }
    public boolean isPrimaryVehicle() { return primaryVehicle; }
}
