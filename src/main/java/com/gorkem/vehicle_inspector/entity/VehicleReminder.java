package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "vehicle_reminders")
public class VehicleReminder {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "vehicle_id", nullable = false)
    private Vehicle vehicle;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "created_by_user_id", nullable = false)
    private User createdBy;

    @Enumerated(EnumType.STRING)
    @Column(name = "reminder_type", nullable = false, length = 40)
    private ReminderType reminderType;

    @Column(length = 120)
    private String title;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(name = "due_mileage")
    private Integer dueMileage;

    @Column(name = "source_date")
    private LocalDate sourceDate;

    @Column(name = "source_mileage")
    private Integer sourceMileage;

    @Column(name = "interval_months")
    private Integer intervalMonths;

    @Column(name = "interval_mileage")
    private Integer intervalMileage;

    @Column(name = "first_inspection")
    private Boolean firstInspection;

    @Column(length = 1000)
    private String note;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    protected VehicleReminder() {}

    public VehicleReminder(Vehicle vehicle, User createdBy, ReminderType type,
                           String title, LocalDate dueDate, Integer dueMileage,
                           String note, LocalDateTime now) {
        this.vehicle = vehicle;
        this.createdBy = createdBy;
        this.createdAt = now;
        update(type, title, dueDate, dueMileage, note, now);
    }

    public VehicleReminder(Vehicle vehicle, User createdBy, ReminderType type,
                           String title, LocalDate dueDate, Integer dueMileage,
                           String note, LocalDate sourceDate, Integer sourceMileage,
                           Integer intervalMonths, Integer intervalMileage,
                           Boolean firstInspection, LocalDateTime now) {
        this.vehicle = vehicle;
        this.createdBy = createdBy;
        this.createdAt = now;
        update(type, title, dueDate, dueMileage, note, sourceDate, sourceMileage,
                intervalMonths, intervalMileage, firstInspection, now);
    }

    public void update(ReminderType type, String title, LocalDate dueDate,
                       Integer dueMileage, String note, LocalDateTime now) {
        update(type, title, dueDate, dueMileage, note,
                null, null, null, null, null, now);
    }

    public void update(ReminderType type, String title, LocalDate dueDate,
                       Integer dueMileage, String note, LocalDate sourceDate,
                       Integer sourceMileage, Integer intervalMonths,
                       Integer intervalMileage, Boolean firstInspection,
                       LocalDateTime now) {
        this.reminderType = type;
        this.title = normalize(title);
        this.dueDate = dueDate;
        this.dueMileage = dueMileage;
        this.sourceDate = sourceDate;
        this.sourceMileage = sourceMileage;
        this.intervalMonths = intervalMonths;
        this.intervalMileage = intervalMileage;
        this.firstInspection = firstInspection;
        this.note = normalize(note);
        this.updatedAt = now;
    }

    public void complete(LocalDateTime now) { this.completedAt = now; this.updatedAt = now; }
    public void reopen(LocalDateTime now) { this.completedAt = null; this.updatedAt = now; }
    private String normalize(String value) { return value == null || value.isBlank() ? null : value.trim(); }

    public Long getId() { return id; }
    public Vehicle getVehicle() { return vehicle; }
    public User getCreatedBy() { return createdBy; }
    public ReminderType getReminderType() { return reminderType; }
    public String getTitle() { return title; }
    public LocalDate getDueDate() { return dueDate; }
    public Integer getDueMileage() { return dueMileage; }
    public LocalDate getSourceDate() { return sourceDate; }
    public Integer getSourceMileage() { return sourceMileage; }
    public Integer getIntervalMonths() { return intervalMonths; }
    public Integer getIntervalMileage() { return intervalMileage; }
    public Boolean getFirstInspection() { return firstInspection; }
    public String getNote() { return note; }
    public LocalDateTime getCompletedAt() { return completedAt; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
}
