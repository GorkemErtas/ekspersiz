package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "damage_assessment_records",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_damage_assessment_record_inspection",
                        columnNames = "inspection_id"
                ),
                @UniqueConstraint(
                        name = "uk_damage_assessment_record_number",
                        columnNames = "record_number"
                )
        }
)
public class DamageAssessmentRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "inspection_id", nullable = false)
    private DamageInspection inspection;

    @Column(name = "record_number", nullable = false, length = 50)
    private String recordNumber;

    @Column(name = "incident_date_time", nullable = false)
    private LocalDateTime incidentDateTime;

    @Column(name = "incident_city", nullable = false, length = 100)
    private String incidentCity;

    @Column(name = "incident_district", length = 100)
    private String incidentDistrict;

    @Column(name = "incident_address", length = 500)
    private String incidentAddress;

    @Column(name = "incident_description", nullable = false, length = 3000)
    private String incidentDescription;

    @Column(name = "declarant_full_name", nullable = false, length = 150)
    private String declarantFullName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private DamageAssessmentRecordStatus status;

    @Column(name = "document_version", nullable = false)
    private Integer documentVersion;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Column(name = "finalized_at")
    private LocalDateTime finalizedAt;

    @Column(name = "snapshot_json", columnDefinition = "TEXT")
    private String snapshotJson;

    @Column(name = "content_hash", length = 64)
    private String contentHash;

    protected DamageAssessmentRecord() {
    }

    public DamageAssessmentRecord(
            DamageInspection inspection,
            String recordNumber,
            LocalDateTime incidentDateTime,
            String incidentCity,
            String incidentDistrict,
            String incidentAddress,
            String incidentDescription,
            String declarantFullName,
            LocalDateTime now
    ) {
        this.inspection = inspection;
        this.recordNumber = recordNumber;
        this.status = DamageAssessmentRecordStatus.DRAFT;
        this.documentVersion = 1;
        this.createdAt = now;
        updateDetails(incidentDateTime, incidentCity, incidentDistrict,
                incidentAddress, incidentDescription, declarantFullName, now);
    }

    public void updateDetails(
            LocalDateTime incidentDateTime,
            String incidentCity,
            String incidentDistrict,
            String incidentAddress,
            String incidentDescription,
            String declarantFullName,
            LocalDateTime now
    ) {
        requireDraft();
        this.incidentDateTime = incidentDateTime;
        this.incidentCity = normalizeRequired(incidentCity);
        this.incidentDistrict = normalizeOptional(incidentDistrict);
        this.incidentAddress = normalizeOptional(incidentAddress);
        this.incidentDescription = normalizeRequired(incidentDescription);
        this.declarantFullName = normalizeRequired(declarantFullName);
        this.updatedAt = now;
    }

    public void finalizeRecord(
            LocalDateTime now,
            String snapshotJson,
            String contentHash
    ) {
        requireDraft();
        if (snapshotJson == null || snapshotJson.isBlank()
                || contentHash == null || contentHash.isBlank()) {
            throw new IllegalArgumentException(
                    "Kesinleştirilen tutanak için belge özeti ve doğrulama değeri zorunludur.");
        }
        this.snapshotJson = snapshotJson;
        this.contentHash = contentHash;
        this.status = DamageAssessmentRecordStatus.FINALIZED;
        this.finalizedAt = now;
        this.updatedAt = now;
    }

    private void requireDraft() {
        if (status == DamageAssessmentRecordStatus.FINALIZED) {
            throw new IllegalStateException("Kesinleştirilmiş tutanak değiştirilemez.");
        }
    }

    private static String normalizeRequired(String value) {
        return value == null ? null : value.trim();
    }

    private static String normalizeOptional(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    public Long getId() { return id; }
    public DamageInspection getInspection() { return inspection; }
    public String getRecordNumber() { return recordNumber; }
    public LocalDateTime getIncidentDateTime() { return incidentDateTime; }
    public String getIncidentCity() { return incidentCity; }
    public String getIncidentDistrict() { return incidentDistrict; }
    public String getIncidentAddress() { return incidentAddress; }
    public String getIncidentDescription() { return incidentDescription; }
    public String getDeclarantFullName() { return declarantFullName; }
    public DamageAssessmentRecordStatus getStatus() { return status; }
    public Integer getDocumentVersion() { return documentVersion; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public LocalDateTime getFinalizedAt() { return finalizedAt; }
    public String getSnapshotJson() { return snapshotJson; }
    public String getContentHash() { return contentHash; }
}
