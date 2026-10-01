package com.gorkem.vehicle_inspector.service;

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

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

@Service
public class DamageAssessmentRecordService {

    private static final DateTimeFormatter RECORD_DATE =
            DateTimeFormatter.ofPattern("yyyyMMdd");

    private final DamageAssessmentRecordRepository repository;
    private final BusinessContextService businessContextService;
    private final InspectionAccessService inspectionAccessService;
    private final Clock clock;

    public DamageAssessmentRecordService(
            DamageAssessmentRecordRepository repository,
            BusinessContextService businessContextService,
            InspectionAccessService inspectionAccessService,
            Clock clock
    ) {
        this.repository = repository;
        this.businessContextService = businessContextService;
        this.inspectionAccessService = inspectionAccessService;
        this.clock = clock;
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

        record.finalizeRecord(LocalDateTime.now(clock));
        return toResponse(repository.save(record));
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
                record.getFinalizedAt()
        );
    }
}
