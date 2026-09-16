package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "vehicle_mileage_records")
public class VehicleMileageRecord {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "vehicle_id", nullable = false)
    private Vehicle vehicle;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recorded_by_user_id", nullable = false)
    private User recordedBy;
    @Column(name = "previous_mileage")
    private Integer previousMileage;
    @Column(name = "new_mileage", nullable = false)
    private Integer newMileage;
    @Column(name = "recorded_at", nullable = false, updatable = false)
    private LocalDateTime recordedAt;

    protected VehicleMileageRecord() {}
    public VehicleMileageRecord(Vehicle vehicle, User recordedBy, Integer previousMileage,
                                Integer newMileage, LocalDateTime recordedAt) {
        this.vehicle = vehicle; this.recordedBy = recordedBy;
        this.previousMileage = previousMileage; this.newMileage = newMileage;
        this.recordedAt = recordedAt;
    }
    public Long getId() { return id; }
    public Vehicle getVehicle() { return vehicle; }
    public User getRecordedBy() { return recordedBy; }
    public Integer getPreviousMileage() { return previousMileage; }
    public Integer getNewMileage() { return newMileage; }
    public LocalDateTime getRecordedAt() { return recordedAt; }
}
