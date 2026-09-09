package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.client.AiAnalysisClient;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.LlmInspectionReportResult;
import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.mapper.DamageInspectionMapper;
import com.gorkem.vehicle_inspector.mapper.InspectionLlmMapper;
import com.gorkem.vehicle_inspector.mapper.InspectionReportMapper;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import com.gorkem.vehicle_inspector.service.report.GeminiInspectionReportService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.stereotype.Service;

import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;

import org.springframework.web.multipart.MultipartFile;

import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

@Service
public class DamageInspectionService {

    private static final Logger log =
            LoggerFactory.getLogger(
                    DamageInspectionService.class
            );

    private final DamageInspectionRepository inspectionRepository;
    private final VehicleRepository vehicleRepository;
    private final UserRepository userRepository;
    private final FileStorageService fileStorageService;
    private final AiAnalysisClient aiAnalysisClient;
    private final GeminiInspectionReportService
            geminiInspectionReportService;
    private final TransactionTemplate transactionTemplate;

    public DamageInspectionService(
            DamageInspectionRepository inspectionRepository,
            VehicleRepository vehicleRepository,
            UserRepository userRepository,
            FileStorageService fileStorageService,
            AiAnalysisClient aiAnalysisClient,
            GeminiInspectionReportService geminiInspectionReportService,
            PlatformTransactionManager transactionManager
    ) {
        this.inspectionRepository =
                inspectionRepository;

        this.vehicleRepository =
                vehicleRepository;

        this.userRepository =
                userRepository;

        this.fileStorageService =
                fileStorageService;

        this.aiAnalysisClient =
                aiAnalysisClient;

        this.geminiInspectionReportService =
                geminiInspectionReportService;

        this.transactionTemplate =
                new TransactionTemplate(
                        transactionManager
                );
    }

    private DamageInspectionResponse buildResponse(
            DamageInspection inspection
    ) {
        InspectionReportResponse report =
                InspectionReportMapper.toResponse(
                        inspection.getReport()
                );

        return DamageInspectionMapper.toResponse(
                inspection,
                report
        );
    }

    @Transactional
    public DamageInspectionResponse createInspection(
            Long vehicleId,
            String city,
            String authenticatedEmail
    ) {
        User user =
                findUserByEmail(
                        authenticatedEmail
                );

        Vehicle vehicle =
                findVehicleByIdAndUserId(
                        vehicleId,
                        user.getId()
                );

        if (city == null || city.isBlank()) {
            throw new IllegalArgumentException(
                    "Şehir bilgisi zorunludur."
            );
        }

        DamageInspection inspection =
                new DamageInspection(
                        vehicle,
                        user,
                        InspectionStatus.PENDING
                );

        inspection.setLocationCity(
                normalizeCity(city)
        );

        inspection.setReportStatus(
                ReportStatus.PENDING
        );

        inspection.setReportMessage(null);

        DamageInspection savedInspection =
                inspectionRepository.save(
                        inspection
                );

        return buildResponse(
                savedInspection
        );
    }

    @Transactional(readOnly = true)
    public List<DamageInspectionResponse>
    getMyInspections(
            String authenticatedEmail
    ) {
        User user =
                findUserByEmail(
                        authenticatedEmail
                );

        return inspectionRepository
                .findAllByUserIdOrderByCreatedAtDesc(
                        user.getId()
                )
                .stream()
                .map(this::buildResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public DamageInspectionResponse
    getMyInspectionById(
            Long inspectionId,
            String authenticatedEmail
    ) {
        User user =
                findUserByEmail(
                        authenticatedEmail
                );

        DamageInspection inspection =
                findInspectionByIdAndUserId(
                        inspectionId,
                        user.getId()
                );

        return buildResponse(
                inspection
        );
    }

    @Transactional(readOnly = true)
    public Path getInspectionImage(
            Long inspectionId,
            String authenticatedEmail
    ) {
        User user =
                findUserByEmail(
                        authenticatedEmail
                );

        DamageInspection inspection =
                findInspectionByIdAndUserId(
                        inspectionId,
                        user.getId()
                );

        validateImageExists(
                inspection
        );

        return fileStorageService
                .resolveStoredFile(
                        inspection.getImagePath()
                );
    }

    @Transactional
    public DamageInspectionResponse uploadInspectionImage(
            Long inspectionId,
            MultipartFile image,
            String authenticatedEmail
    ) {
        User user =
                findUserByEmail(
                        authenticatedEmail
                );

        DamageInspection inspection =
                findInspectionByIdAndUserId(
                        inspectionId,
                        user.getId()
                );

        String previousImagePath =
                inspection.getImagePath();

        String storedFilename =
                fileStorageService.storeImage(
                        image
                );

        String newImagePath =
                storedFilename;

        registerImageCleanup(
                previousImagePath,
                newImagePath
        );

        inspection.setImagePath(
                newImagePath
        );

        inspection.clearDetections();
        inspection.clearRepairRecommendations();

        inspection.setReport(null);

        inspection.setReportStatus(
                ReportStatus.PENDING
        );

        inspection.setReportMessage(null);

        inspection.setStatus(
                InspectionStatus.PENDING
        );

        inspection.setDamageSeverity(null);
        inspection.setConfidenceScore(null);
        inspection.setAnalysisMessage(null);
        inspection.setCompletedAt(null);

        DamageInspection updatedInspection =
                inspectionRepository.save(
                        inspection
                );

        return buildResponse(
                updatedInspection
        );
    }

    private void registerImageCleanup(
            String previousImagePath,
            String newImagePath
    ) {
        if (!TransactionSynchronizationManager
                .isSynchronizationActive()) {

            throw new IllegalStateException(
                    "Fotoğraf işlemi aktif bir transaction gerektiriyor."
            );
        }

        TransactionSynchronizationManager
                .registerSynchronization(
                        new TransactionSynchronization() {

                            @Override
                            public void afterCompletion(
                                    int status
                            ) {
                                if (status ==
                                        TransactionSynchronization
                                                .STATUS_COMMITTED) {

                                    deleteImageSafely(
                                            previousImagePath
                                    );

                                } else {

                                    deleteImageSafely(
                                            newImagePath
                                    );
                                }
                            }
                        }
                );
    }

    private void deleteImageSafely(
            String imagePath
    ) {
        if (imagePath == null
                || imagePath.isBlank()) {

            return;
        }

        try {
            fileStorageService
                    .deleteStoredFile(
                            imagePath
                    );

        } catch (RuntimeException exception) {

            log.error(
                    "Stored image could not be deleted: {}",
                    imagePath,
                    exception
            );
        }
    }

    public DamageInspectionResponse analyzeInspection(
            Long inspectionId,
            String authenticatedEmail
    ) {
        AnalysisContext context =
                transactionTemplate.execute(
                        status -> {

                            User user =
                                    findUserByEmail(
                                            authenticatedEmail
                                    );

                            DamageInspection inspection =
                                    findInspectionByIdAndUserId(
                                            inspectionId,
                                            user.getId()
                                    );

                            validateImageExists(
                                    inspection
                            );

                            inspection.setStatus(
                                    InspectionStatus.PROCESSING
                            );

                            inspection.setAnalysisMessage(
                                    null
                            );

                            inspection.setCompletedAt(
                                    null
                            );

                            inspectionRepository.save(
                                    inspection
                            );

                            return new AnalysisContext(
                                    inspection.getId(),
                                    user.getId(),
                                    inspection.getImagePath()
                            );
                        }
                );

        if (context == null) {
            throw new IllegalStateException(
                    "Analiz başlatılamadı."
            );
        }

        AiAnalysisResponse aiResponse;

        try {
            Path storedImagePath =
                    fileStorageService
                            .resolveStoredFile(
                                    context.imagePath()
                            );

            aiResponse =
                    aiAnalysisClient.analyze(
                            storedImagePath
                    );

        } catch (RuntimeException exception) {

            return markAnalysisAsFailed(
                    context,
                    exception
            );
        }

        return persistAnalysisResult(
                context,
                aiResponse
        );
    }

    private DamageInspectionResponse persistAnalysisResult(
            AnalysisContext context,
            AiAnalysisResponse aiResponse
    ) {
        transactionTemplate.executeWithoutResult(
                status -> {

                    DamageInspection inspection =
                            findInspectionByIdAndUserId(
                                    context.inspectionId(),
                                    context.userId()
                            );

                    inspection.clearDetections();
                    inspection.clearRepairRecommendations();

                    saveDetections(
                            inspection,
                            aiResponse.getDetections()
                    );

                    saveRepairRecommendations(
                            inspection,
                            aiResponse.getRepairRecommendations()
                    );

                    inspection.setDamageSeverity(
                            aiResponse.getDamageSeverity()
                    );

                    inspection.setConfidenceScore(
                            aiResponse.getConfidenceScore()
                    );

                    inspection.setAnalysisMessage(
                            aiResponse.getAnalysisMessage()
                    );

                    inspection.setStatus(
                            InspectionStatus.COMPLETED
                    );

                    inspection.setCompletedAt(
                            LocalDateTime.now()
                    );

                    inspection.setReportStatus(
                            ReportStatus.PROCESSING
                    );

                    inspection.setReportMessage(
                            null
                    );

                    inspectionRepository.save(
                            inspection
                    );
                }
        );

        generateReportOutsideTransaction(
                context
        );

        DamageInspectionResponse response =
                transactionTemplate.execute(
                        status -> {

                            DamageInspection inspection =
                                    findInspectionByIdAndUserId(
                                            context.inspectionId(),
                                            context.userId()
                                    );

                            return buildResponse(
                                    inspection
                            );
                        }
                );

        if (response == null) {
            throw new IllegalStateException(
                    "Analiz sonucu alınamadı."
            );
        }

        return response;
    }

    private void generateReportOutsideTransaction(
            AnalysisContext context
    ) {
        InspectionLlmRequest request =
                transactionTemplate.execute(
                        status -> {

                            DamageInspection inspection =
                                    findInspectionByIdAndUserId(
                                            context.inspectionId(),
                                            context.userId()
                                    );

                            return InspectionLlmMapper
                                    .toRequest(
                                            inspection
                                    );
                        }
                );

        if (request == null) {

            markReportAsFailed(
                    context.inspectionId(),
                    context.userId()
            );

            return;
        }

        try {
            LlmInspectionReportResult result =
                    geminiInspectionReportService
                            .generateReport(
                                    request
                            );

            saveGeneratedReport(
                    context.inspectionId(),
                    context.userId(),
                    result
            );

        } catch (RuntimeException exception) {

            log.error(
                    "Gemini report generation failed for inspection {}",
                    context.inspectionId(),
                    exception
            );

            markReportAsFailed(
                    context.inspectionId(),
                    context.userId()
            );
        }
    }

    private void saveGeneratedReport(
            Long inspectionId,
            Long userId,
            LlmInspectionReportResult result
    ) {
        if (result == null) {
            throw new IllegalArgumentException(
                    "Rapor sonucu boş olamaz."
            );
        }

        transactionTemplate.executeWithoutResult(
                status -> {

                    DamageInspection inspection =
                            findInspectionByIdAndUserId(
                                    inspectionId,
                                    userId
                            );

                    InspectionReport generatedReport =
                            new InspectionReport(
                                    inspection,
                                    result.title,
                                    result.summary,
                                    result.damageDescription,
                                    result.repairRecommendation,
                                    result.estimatedMinimumPrice,
                                    result.estimatedMaximumPrice,
                                    result.currency,
                                    result.priceInformation,
                                    result.priceSourceDescription,
                                    result.disclaimer
                            );

                    InspectionReport existingReport =
                            inspection.getReport();

                    if (existingReport == null) {

                        inspection.setReport(
                                generatedReport
                        );

                    } else {

                        existingReport.updateFrom(
                                generatedReport
                        );
                    }

                    inspection.setReportStatus(
                            ReportStatus.COMPLETED
                    );

                    inspection.setReportMessage(
                            null
                    );

                    inspectionRepository.save(
                            inspection
                    );
                }
        );
    }

    private void markReportAsFailed(
            Long inspectionId,
            Long userId
    ) {
        transactionTemplate.executeWithoutResult(
                status -> {

                    DamageInspection inspection =
                            findInspectionByIdAndUserId(
                                    inspectionId,
                                    userId
                            );

                    inspection.setReportStatus(
                            ReportStatus.FAILED
                    );

                    inspection.setReportMessage(
                            "AI raporu şu anda oluşturulamadı."
                    );

                    inspectionRepository.save(
                            inspection
                    );
                }
        );
    }

    private DamageInspectionResponse markAnalysisAsFailed(
            AnalysisContext context,
            RuntimeException exception
    ) {
        log.error(
                "Damage analysis failed for inspection {}",
                context.inspectionId(),
                exception
        );

        DamageInspectionResponse response =
                transactionTemplate.execute(
                        status -> {

                            DamageInspection inspection =
                                    findInspectionByIdAndUserId(
                                            context.inspectionId(),
                                            context.userId()
                                    );

                            inspection.setStatus(
                                    InspectionStatus.FAILED
                            );

                            inspection.setCompletedAt(
                                    null
                            );

                            inspection.setAnalysisMessage(
                                    buildAnalysisErrorMessage(
                                            exception
                                    )
                            );

                            inspection.setReportStatus(
                                    ReportStatus.FAILED
                            );

                            inspection.setReportMessage(
                                    "ML analizi tamamlanamadığı için "
                                            + "rapor oluşturulamadı."
                            );

                            DamageInspection savedInspection =
                                    inspectionRepository.save(
                                            inspection
                                    );

                            return buildResponse(
                                    savedInspection
                            );
                        }
                );

        if (response == null) {
            throw new IllegalStateException(
                    "Analiz hata durumu kaydedilemedi."
            );
        }

        return response;
    }

    private String buildAnalysisErrorMessage(
            RuntimeException exception
    ) {
        if (exception instanceof IllegalStateException
                && exception.getMessage() != null
                && !exception.getMessage().isBlank()) {

            return exception.getMessage();
        }

        return "Hasar analizi sırasında bir hata oluştu. "
                + "Lütfen tekrar deneyin.";
    }

    public DamageInspectionResponse regenerateReport(
            Long inspectionId,
            String authenticatedEmail
    ) {
        ReportGenerationContext context =
                transactionTemplate.execute(
                        status -> {

                            User user =
                                    findUserByEmail(
                                            authenticatedEmail
                                    );

                            DamageInspection inspection =
                                    findInspectionByIdAndUserId(
                                            inspectionId,
                                            user.getId()
                                    );

                            if (inspection.getStatus()
                                    != InspectionStatus.COMPLETED) {

                                throw new IllegalStateException(
                                        "Rapor oluşturmak için ML analizi "
                                                + "tamamlanmış olmalıdır."
                                );
                            }

                            if (inspection.getDamageSeverity()
                                    == null) {

                                throw new IllegalStateException(
                                        "İncelemeye ait ML analiz sonucu "
                                                + "bulunamadı."
                                );
                            }

                            inspection.setReportStatus(
                                    ReportStatus.PROCESSING
                            );

                            inspection.setReportMessage(
                                    null
                            );

                            inspectionRepository.save(
                                    inspection
                            );

                            InspectionLlmRequest request =
                                    InspectionLlmMapper
                                            .toRequest(
                                                    inspection
                                            );

                            return new ReportGenerationContext(
                                    inspection.getId(),
                                    user.getId(),
                                    request
                            );
                        }
                );

        if (context == null) {
            throw new IllegalStateException(
                    "Rapor oluşturma işlemi başlatılamadı."
            );
        }

        try {
            LlmInspectionReportResult result =
                    geminiInspectionReportService
                            .generateReport(
                                    context.request()
                            );

            saveGeneratedReport(
                    context.inspectionId(),
                    context.userId(),
                    result
            );

        } catch (RuntimeException exception) {

            log.error(
                    "Gemini report regeneration failed for inspection {}",
                    context.inspectionId(),
                    exception
            );

            markReportAsFailed(
                    context.inspectionId(),
                    context.userId()
            );
        }

        DamageInspectionResponse response =
                transactionTemplate.execute(
                        status -> {

                            DamageInspection inspection =
                                    findInspectionByIdAndUserId(
                                            context.inspectionId(),
                                            context.userId()
                                    );

                            return buildResponse(
                                    inspection
                            );
                        }
                );

        if (response == null) {
            throw new IllegalStateException(
                    "Rapor sonucu alınamadı."
            );
        }

        return response;
    }

    private void validateImageExists(
            DamageInspection inspection
    ) {
        if (inspection.getImagePath() == null
                || inspection.getImagePath().isBlank()) {

            throw new IllegalStateException(
                    "Analizden önce fotoğraf "
                            + "yüklenmelidir."
            );
        }
    }

    private void saveDetections(
            DamageInspection inspection,
            List<DetectedObjectResponse> detections
    ) {
        if (detections == null) {
            return;
        }

        for (DetectedObjectResponse detectedObject
                : detections) {

            if (detectedObject == null
                    || detectedObject
                    .getBoundingBox() == null) {

                continue;
            }

            BoundingBoxResponse boundingBox =
                    detectedObject.getBoundingBox();

            if (boundingBox.getX1() == null
                    || boundingBox.getY1() == null
                    || boundingBox.getX2() == null
                    || boundingBox.getY2() == null) {

                continue;
            }

            DamageDetection detection =
                    new DamageDetection(
                            inspection,
                            detectedObject.getLabel(),
                            detectedObject.getConfidence(),
                            detectedObject.getAffectedPart(),
                            boundingBox.getX1(),
                            boundingBox.getY1(),
                            boundingBox.getX2(),
                            boundingBox.getY2()
                    );

            inspection.addDetection(
                    detection
            );
        }
    }

    private void saveRepairRecommendations(
            DamageInspection inspection,
            List<RepairRecommendationResponse>
                    recommendationResponses
    ) {
        if (recommendationResponses == null) {
            return;
        }

        for (RepairRecommendationResponse response
                : recommendationResponses) {

            if (response == null
                    || response.getDamageType() == null
                    || response.getRecommendedAction()
                    == null) {

                continue;
            }

            Set<VehiclePart> recommendationParts =
                    new LinkedHashSet<>();

            if (response.getAffectedParts() != null) {

                response.getAffectedParts()
                        .stream()
                        .filter(Objects::nonNull)
                        .filter(
                                part ->
                                        part
                                                != VehiclePart.UNKNOWN
                        )
                        .forEach(
                                recommendationParts::add
                        );
            }

            DamageRepairRecommendation recommendation =
                    new DamageRepairRecommendation(
                            inspection,
                            response.getDamageType(),
                            response.getRecommendedAction(),
                            Boolean.TRUE.equals(
                                    response
                                            .getPartReplacementRequired()
                            ),
                            recommendationParts
                    );

            inspection.addRepairRecommendation(
                    recommendation
            );
        }
    }

    private User findUserByEmail(
            String email
    ) {
        return userRepository
                .findByEmail(
                        email.trim()
                                .toLowerCase()
                )
                .orElseThrow(
                        () ->
                                new ResourceNotFoundException(
                                        "Kullanıcı bulunamadı."
                                )
                );
    }

    private DamageInspection
    findInspectionByIdAndUserId(
            Long inspectionId,
            Long userId
    ) {
        return inspectionRepository
                .findByIdAndUserId(
                        inspectionId,
                        userId
                )
                .orElseThrow(
                        () ->
                                new ResourceNotFoundException(
                                        "Hasar incelemesi "
                                                + "bulunamadı. ID: "
                                                + inspectionId
                                )
                );
    }

    private Vehicle findVehicleByIdAndUserId(
            Long vehicleId,
            Long userId
    ) {
        return vehicleRepository
                .findByIdAndUserId(
                        vehicleId,
                        userId
                )
                .orElseThrow(
                        () ->
                                new ResourceNotFoundException(
                                        "Araç bulunamadı. ID: "
                                                + vehicleId
                                )
                );
    }

    private String normalizeCity(
            String city
    ) {
        String normalized =
                city.trim();

        if (normalized.length() > 100) {
            throw new IllegalArgumentException(
                    "Şehir adı en fazla "
                            + "100 karakter olabilir."
            );
        }

        return normalized;
    }

    private record AnalysisContext(
            Long inspectionId,
            Long userId,
            String imagePath
    ) {
    }

    private record ReportGenerationContext(
            Long inspectionId,
            Long userId,
            InspectionLlmRequest request
    ) {
    }
}