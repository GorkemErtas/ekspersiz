package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "maintenance_records")
public class MaintenanceRecord {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "vehicle_id", nullable = false)
    private Vehicle vehicle;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "created_by_user_id", nullable = false)
    private User createdBy;

    @Enumerated(EnumType.STRING)
    @Column(name = "maintenance_type", nullable = false, length = 40)
    private MaintenanceType maintenanceType;

    @Column(name = "maintenance_date", nullable = false)
    private LocalDate maintenanceDate;

    @Column(nullable = false)
    private Integer mileage;

    @Column(precision = 12, scale = 2)
    private BigDecimal cost;

    @Column(length = 1000)
    private String note;

    @Column(name = "next_recommended_date")
    private LocalDate nextRecommendedDate;

    @Column(name = "next_recommended_mileage")
    private Integer nextRecommendedMileage;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    protected MaintenanceRecord() {}

    public MaintenanceRecord(Vehicle vehicle, User createdBy, MaintenanceType maintenanceType,
                             LocalDate maintenanceDate, Integer mileage, BigDecimal cost,
                             String note, LocalDate nextRecommendedDate,
                             Integer nextRecommendedMileage, LocalDateTime now) {
        this.vehicle = vehicle;
        this.createdBy = createdBy;
        update(maintenanceType, maintenanceDate, mileage, cost, note,
                nextRecommendedDate, nextRecommendedMileage, now);
        this.createdAt = now;
    }

    public void update(MaintenanceType type, LocalDate date, Integer mileage,
                       BigDecimal cost, String note, LocalDate nextDate,
                       Integer nextMileage, LocalDateTime now) {
        this.maintenanceType = type;
        this.maintenanceDate = date;
        this.mileage = mileage;
        this.cost = cost;
        this.note = normalize(note);
        this.nextRecommendedDate = nextDate;
        this.nextRecommendedMileage = nextMileage;
        this.updatedAt = now;
    }

    private String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    public Long getId() { return id; }
    public Vehicle getVehicle() { return vehicle; }
    public User getCreatedBy() { return createdBy; }
    public MaintenanceType getMaintenanceType() { return maintenanceType; }
    public LocalDate getMaintenanceDate() { return maintenanceDate; }
    public Integer getMileage() { return mileage; }
    public BigDecimal getCost() { return cost; }
    public String getNote() { return note; }
    public LocalDate getNextRecommendedDate() { return nextRecommendedDate; }
    public Integer getNextRecommendedMileage() { return nextRecommendedMileage; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
}
