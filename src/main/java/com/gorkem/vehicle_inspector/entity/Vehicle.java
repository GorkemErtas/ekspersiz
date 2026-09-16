package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

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

    @Column(length = 1000)
    private String notes;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(
            name = "user_id",
            foreignKey = @ForeignKey(
                    name = "fk_vehicle_user"
            )
    )
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(
            name = "business_account_id",
            foreignKey = @ForeignKey(
                    name = "fk_vehicle_business_account"
            )
    )
    private BusinessAccount businessAccount;

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

    public Vehicle(
            String plate,
            String brand,
            String model,
            Integer modelYear,
            Integer mileage,
            BusinessAccount businessAccount
    ) {
        this.plate = plate;
        this.brand = brand;
        this.model = model;
        this.modelYear = modelYear;
        this.mileage = mileage;
        this.user = null;
        this.businessAccount = businessAccount;
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

    public BusinessAccount getBusinessAccount() {
        return businessAccount;
    }

    public void assignToUser(User user) {
        this.user = user;
        this.businessAccount = null;
    }

    public void assignToBusiness(
            BusinessAccount businessAccount
    ) {
        this.user = null;
        this.businessAccount = businessAccount;
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

    public String getNotes() { return notes; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setNotes(String notes) {
        this.notes = notes == null || notes.isBlank() ? null : notes.trim();
    }
    public void initializeCreatedAt(LocalDateTime now) {
        if (createdAt == null) createdAt = now;
    }
}
