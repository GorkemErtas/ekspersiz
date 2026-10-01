package com.gorkem.vehicle_inspector.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.dto.request.DamageAssessmentRecordRequest;
import com.gorkem.vehicle_inspector.dto.response.DamageAssessmentRecordResponse;
import com.gorkem.vehicle_inspector.entity.DamageAssessmentRecord;
import com.gorkem.vehicle_inspector.entity.DamageInspection;
import com.gorkem.vehicle_inspector.entity.InspectionStatus;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.DamageAssessmentRecordRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

@Service
public class DamageAssessmentRecordService {

    private static final DateTimeFormatter RECORD_DATE =
            DateTimeFormatter.ofPattern("yyyyMMdd");

    private final DamageAssessmentRecordRepository repository;
    private final BusinessContextService businessContextService;
    private final InspectionAccessService inspectionAccessService;
    private final Clock clock;
    private final ObjectMapper objectMapper;

    public DamageAssessmentRecordService(
            DamageAssessmentRecordRepository repository,
            BusinessContextService businessContextService,
            InspectionAccessService inspectionAccessService,
            Clock clock,
            ObjectMapper objectMapper
    ) {
        this.repository = repository;
        this.businessContextService = businessContextService;
        this.inspectionAccessService = inspectionAccessService;
        this.clock = clock;
        this.objectMapper = objectMapper;
    }

    @Transactional(readOnly = true)
    public DamageAssessmentRecordResponse get(Long inspectionId, String email) {
        User user = businessContextService.requireUser(email);
        DamageInspection inspection =
                inspectionAccessService.requireInspection(inspectionId, user);

        DamageAssessmentRecord record = repository.findByInspectionId(inspection.getId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Bu inceleme için tutanak bulunamadı."));

        return toResponse(record);
    }

    @Transactional
    public DamageAssessmentRecordResponse create(
            Long inspectionId,
            DamageAssessmentRecordRequest request,
            String email
    ) {
        User user = businessContextService.requireUser(email);
        DamageInspection inspection =
                inspectionAccessService.requireInspectionForUpdate(inspectionId, user);

        if (inspection.getStatus() != InspectionStatus.COMPLETED) {
            throw new IllegalStateException(
                    "Tutanak yalnızca tamamlanmış analizler için oluşturulabilir.");
        }

        if (repository.existsByInspectionId(inspection.getId())) {
            throw new IllegalStateException(
                    "Bu inceleme için daha önce tutanak oluşturulmuş.");
        }

        LocalDateTime now = LocalDateTime.now(clock);
        DamageAssessmentRecord record = new DamageAssessmentRecord(
                inspection,
                nextRecordNumber(now),
                request.incidentDateTime(),
                request.incidentCity(),
                request.incidentDistrict(),
                request.incidentAddress(),
                request.incidentDescription(),
                request.declarantFullName(),
                now
        );

        return toResponse(repository.save(record));
    }

    @Transactional
    public DamageAssessmentRecordResponse update(
            Long inspectionId,
            DamageAssessmentRecordRequest request,
            String email
    ) {
        User user = businessContextService.requireUser(email);
        DamageInspection inspection =
                inspectionAccessService.requireInspectionForUpdate(inspectionId, user);

        DamageAssessmentRecord record = repository.findByInspectionId(inspection.getId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Bu inceleme için tutanak bulunamadı."));

        record.updateDetails(
                request.incidentDateTime(),
                request.incidentCity(),
                request.incidentDistrict(),
                request.incidentAddress(),
                request.incidentDescription(),
                request.declarantFullName(),
                LocalDateTime.now(clock)
        );

        return toResponse(repository.save(record));
    }

    @Transactional
    public DamageAssessmentRecordResponse finalizeRecord(
            Long inspectionId,
            String email
    ) {
        User user = businessContextService.requireUser(email);
        DamageInspection inspection =
                inspectionAccessService.requireInspectionForUpdate(inspectionId, user);

        DamageAssessmentRecord record = repository.findByInspectionId(inspection.getId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Bu inceleme için tutanak bulunamadı."));

        LocalDateTime now = LocalDateTime.now(clock);
        String snapshotJson = buildSnapshotJson(record, inspection, now);
        record.finalizeRecord(now, snapshotJson, sha256(snapshotJson));
        return toResponse(repository.save(record));
    }


    private String buildSnapshotJson(
            DamageAssessmentRecord record,
            DamageInspection inspection,
            LocalDateTime finalizedAt
    ) {
        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("documentVersion", record.getDocumentVersion());
        snapshot.put("recordNumber", record.getRecordNumber());
        snapshot.put("finalizedAt", finalizedAt);
        snapshot.put("incidentDateTime", record.getIncidentDateTime());
        snapshot.put("incidentCity", record.getIncidentCity());
        snapshot.put("incidentDistrict", record.getIncidentDistrict());
        snapshot.put("incidentAddress", record.getIncidentAddress());
        snapshot.put("incidentDescription", record.getIncidentDescription());
        snapshot.put("declarantFullName", record.getDeclarantFullName());

        Map<String, Object> vehicle = new LinkedHashMap<>();
        vehicle.put("plate", inspection.getVehicle().getPlate());
        vehicle.put("brand", inspection.getVehicle().getBrand());
        vehicle.put("model", inspection.getVehicle().getModel());
        vehicle.put("modelYear", inspection.getVehicle().getModelYear());
        vehicle.put("mileage", inspection.getVehicle().getMileage());
        snapshot.put("vehicle", vehicle);

        Map<String, Object> analysis = new LinkedHashMap<>();
        analysis.put("inspectionId", inspection.getId());
        analysis.put("damageSeverity", inspection.getDamageSeverity());
        analysis.put("confidenceScore", inspection.getConfidenceScore());
        analysis.put("analysisMessage", inspection.getAnalysisMessage());
        analysis.put("imagePath", inspection.getImagePath());
        analysis.put("completedAt", inspection.getCompletedAt());
        analysis.put("detections", inspection.getDetections().stream()
                .map(detection -> Map.of(
                        "label", detection.getLabel(),
                        "confidence", detection.getConfidence(),
                        "affectedPart", detection.getAffectedPart() == null
                                ? "" : detection.getAffectedPart().name()
                ))
                .toList());
        analysis.put("repairRecommendations",
                inspection.getRepairRecommendations().stream()
                        .map(recommendation -> {
                            Map<String, Object> item = new LinkedHashMap<>();
                            item.put("damageType", recommendation.getDamageType());
                            item.put("recommendedAction",
                                    recommendation.getRecommendedAction());
                            item.put("partReplacementRequired",
                                    recommendation.getPartReplacementRequired());
                            item.put("affectedParts",
                                    recommendation.getAffectedParts().stream()
                                            .map(Enum::name)
                                            .sorted()
                                            .toList());
                            return item;
                        })
                        .toList());
        snapshot.put("analysis", analysis);

        if (inspection.getReport() != null) {
            var report = inspection.getReport();
            Map<String, Object> reportSnapshot = new LinkedHashMap<>();
            reportSnapshot.put("title", report.getTitle());
            reportSnapshot.put("summary", report.getSummary());
            reportSnapshot.put("damageDescription", report.getDamageDescription());
            reportSnapshot.put("repairRecommendation",
                    report.getRepairRecommendation());
            reportSnapshot.put("estimatedMinimumPrice",
                    report.getEstimatedMinimumPrice());
            reportSnapshot.put("estimatedMaximumPrice",
                    report.getEstimatedMaximumPrice());
            reportSnapshot.put("currency", report.getCurrency());
            reportSnapshot.put("priceInformation", report.getPriceInformation());
            reportSnapshot.put("priceSourceDescription",
                    report.getPriceSourceDescription());
            reportSnapshot.put("disclaimer", report.getDisclaimer());
            reportSnapshot.put("generatedAt", report.getGeneratedAt());
            snapshot.put("report", reportSnapshot);
        } else {
            snapshot.put("report", null);
        }

        try {
            return objectMapper.writeValueAsString(snapshot);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException(
                    "Tutanak içeriği oluşturulamadı.", exception);
        }
    }

    private String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(
                    digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(
                    "Tutanak doğrulama değeri oluşturulamadı.", exception);
        }
    }

    private String nextRecordNumber(LocalDateTime now) {
        for (int attempt = 0; attempt < 5; attempt++) {
            String suffix = UUID.randomUUID()
                    .toString()
                    .replace("-", "")
                    .substring(0, 8)
                    .toUpperCase();
            String candidate = "EKS-" + RECORD_DATE.format(now) + "-" + suffix;
            if (!repository.existsByRecordNumber(candidate)) {
                return candidate;
            }
        }
        throw new IllegalStateException("Tutanak numarası oluşturulamadı.");
    }

    private DamageAssessmentRecordResponse toResponse(
            DamageAssessmentRecord record
    ) {
        return new DamageAssessmentRecordResponse(
                record.getId(),
                record.getInspection().getId(),
                record.getRecordNumber(),
                record.getStatus(),
                record.getDocumentVersion(),
                record.getIncidentDateTime(),
                record.getIncidentCity(),
                record.getIncidentDistrict(),
                record.getIncidentAddress(),
                record.getIncidentDescription(),
                record.getDeclarantFullName(),
                record.getCreatedAt(),
                record.getUpdatedAt(),
                record.getFinalizedAt(),
                record.getSnapshotJson(),
                record.getContentHash()
        );
    }
}
