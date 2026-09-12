package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "vehicles")
public class Vehicle {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 20)
    private String plate;

    @Column(nullable = false, length = 50)
    private String brand;

    @Column(nullable = false, length = 50)
    private String model;

    @Column(name = "model_year", nullable = false)
    private Integer modelYear;

    @Column(nullable = false)
    private Integer mileage;

    @Column(nullable = false)
    private boolean archived = false;

    @Column(name = "primary_vehicle", nullable = false)
    private boolean primaryVehicle = false;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(
            name = "user_id",
            nullable = false,
            foreignKey = @ForeignKey(
                    name = "fk_vehicle_user"
            )
    )
    private User user;

    protected Vehicle() {
    }

    public Vehicle(
            String plate,
            String brand,
            String model,
            Integer modelYear,
            Integer mileage,
            User user
    ) {
        this.plate = plate;
        this.brand = brand;
        this.model = model;
        this.modelYear = modelYear;
        this.mileage = mileage;
        this.user = user;
        this.archived = false;
        this.primaryVehicle = false;
    }

    public Long getId() {
        return id;
    }

    public String getPlate() {
        return plate;
    }

    public String getBrand() {
        return brand;
    }

    public String getModel() {
        return model;
    }

    public Integer getModelYear() {
        return modelYear;
    }

    public Integer getMileage() {
        return mileage;
    }

    public User getUser() {
        return user;
    }

    public void setPlate(String plate) {
        this.plate = plate;
    }

    public void setBrand(String brand) {
        this.brand = brand;
    }

    public void setModel(String model) {
        this.model = model;
    }

    public void setModelYear(Integer modelYear) {
        this.modelYear = modelYear;
    }

    public void setMileage(Integer mileage) {
        this.mileage = mileage;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public boolean isArchived() {
        return archived;
    }

    public void setArchived(boolean archived) {
        this.archived = archived;
    }

    public boolean isPrimaryVehicle() {
        return primaryVehicle;
    }

    public void setPrimaryVehicle(boolean primaryVehicle) {
        this.primaryVehicle = primaryVehicle;
    }
}