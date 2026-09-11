package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "damage_inspections")
public class DamageInspection {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(
            fetch = FetchType.LAZY,
            optional = false
    )
    @JoinColumn(
            name = "vehicle_id",
            nullable = false,
            foreignKey = @ForeignKey(
                    name = "fk_inspection_vehicle"
            )
    )
    private Vehicle vehicle;

    @ManyToOne(
            fetch = FetchType.LAZY,
            optional = false
    )
    @JoinColumn(
            name = "user_id",
            nullable = false,
            foreignKey = @ForeignKey(
                    name = "fk_inspection_user"
            )
    )
    private User user;

    @Column(
            name = "location_city",
            length = 100
    )
    private String locationCity;

    @OneToMany(
            mappedBy = "inspection",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    private List<DamageDetection> detections =
            new ArrayList<>();

    @OneToMany(
            mappedBy = "inspection",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    private List<DamageRepairRecommendation>
            repairRecommendations = new ArrayList<>();

    @Column(name = "image_path", length = 500)
    private String imagePath;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private InspectionStatus status;

    @Enumerated(EnumType.STRING)
    @Column(
            name = "damage_severity",
            length = 30
    )
    private DamageSeverity damageSeverity;

    @Column(name = "confidence_score")
    private Double confidenceScore;

    @Column(
            name = "analysis_message",
            length = 1000
    )
    private String analysisMessage;

    @Column(
            name = "created_at",
            nullable = false,
            updatable = false
    )
    private LocalDateTime createdAt;

    @Column(name = "analysis_started_at")
    private LocalDateTime analysisStartedAt;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @OneToOne(
            mappedBy = "inspection",
            cascade = CascadeType.ALL,
            orphanRemoval = true,
            fetch = FetchType.LAZY
    )
    private InspectionReport report;

    @Enumerated(EnumType.STRING)
    @Column(
            name = "report_status",
            length = 30
    )
    private ReportStatus reportStatus;

    @Column(
            name = "report_message",
            length = 1000
    )
    private String reportMessage;

    protected DamageInspection() {
    }

    public DamageInspection(
            Vehicle vehicle,
            User user,
            InspectionStatus status
    ) {
        this.vehicle = vehicle;
        this.user = user;
        this.status = status;
    }

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }

    public Long getId() {
        return id;
    }

    public Vehicle getVehicle() {
        return vehicle;
    }

    public User getUser() {
        return user;
    }

    public String getLocationCity() {
        return locationCity;
    }

    public List<DamageDetection> getDetections() {
        return detections;
    }

    public List<DamageRepairRecommendation>
    getRepairRecommendations() {
        return repairRecommendations;
    }

    public String getImagePath() {
        return imagePath;
    }

    public InspectionStatus getStatus() {
        return status;
    }

    public DamageSeverity getDamageSeverity() {
        return damageSeverity;
    }

    public Double getConfidenceScore() {
        return confidenceScore;
    }

    public String getAnalysisMessage() {
        return analysisMessage;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getCompletedAt() {
        return completedAt;
    }

    public InspectionReport getReport() {
        return report;
    }

    public ReportStatus getReportStatus() {
        return reportStatus;
    }

    public String getReportMessage() {
        return reportMessage;
    }

    public void setVehicle(Vehicle vehicle) {
        this.vehicle = vehicle;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public void setLocationCity(
            String locationCity
    ) {
        this.locationCity = locationCity;
    }

    public void setImagePath(String imagePath) {
        this.imagePath = imagePath;
    }

    public void setStatus(
            InspectionStatus status
    ) {
        this.status = status;
    }

    public void setDamageSeverity(
            DamageSeverity damageSeverity
    ) {
        this.damageSeverity = damageSeverity;
    }

    public void setConfidenceScore(
            Double confidenceScore
    ) {
        this.confidenceScore = confidenceScore;
    }

    public void setAnalysisMessage(
            String analysisMessage
    ) {
        this.analysisMessage = analysisMessage;
    }

    public void setCompletedAt(
            LocalDateTime completedAt
    ) {
        this.completedAt = completedAt;
    }

    public void setReport(
            InspectionReport report
    ) {
        this.report = report;

        if (report != null) {
            report.setInspection(this);
        }
    }

    public void setReportStatus(
            ReportStatus reportStatus
    ) {
        this.reportStatus = reportStatus;
    }

    public void setReportMessage(
            String reportMessage
    ) {
        this.reportMessage = reportMessage;
    }

    public void addRepairRecommendation(
            DamageRepairRecommendation recommendation
    ) {
        repairRecommendations.add(
                recommendation
        );

        recommendation.setInspection(this);
    }

    public void clearRepairRecommendations() {
        repairRecommendations.clear();
    }

    public void addDetection(
            DamageDetection detection
    ) {
        detections.add(detection);
        detection.setInspection(this);
    }

    public LocalDateTime getAnalysisStartedAt() {
        return analysisStartedAt;
    }

    public void setAnalysisStartedAt(
            LocalDateTime analysisStartedAt
    ) {
        this.analysisStartedAt = analysisStartedAt;
    }

    public void clearDetections() {
        detections.clear();
    }
}