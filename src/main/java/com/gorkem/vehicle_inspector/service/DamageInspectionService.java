package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.client.AiAnalysisClient;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.LlmInspectionReportResult;
import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.AiServiceException;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.exception.UnsuitableInspectionImageException;
import com.gorkem.vehicle_inspector.mapper.DamageInspectionMapper;
import com.gorkem.vehicle_inspector.mapper.InspectionLlmMapper;
import com.gorkem.vehicle_inspector.mapper.InspectionReportMapper;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.repository.BusinessAccountRepository;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
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

import java.math.BigDecimal;
import java.nio.file.Path;
import java.time.Clock;
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
    private final BusinessContextService businessContextService;
    private final InspectionAccessService inspectionAccessService;
    private final BusinessAccountRepository businessAccountRepository;
    private final UserRepository userRepository;
    private final Clock clock;
    private final FileStorageService fileStorageService;
    private final AiAnalysisClient aiAnalysisClient;
    private final GeminiInspectionReportService
            geminiInspectionReportService;
    private final TransactionTemplate transactionTemplate;
    private final SubscriptionService subscriptionService;

    public DamageInspectionService(
            DamageInspectionRepository inspectionRepository,
            VehicleRepository vehicleRepository,
            BusinessContextService businessContextService,
            InspectionAccessService inspectionAccessService,
            BusinessAccountRepository businessAccountRepository,
            UserRepository userRepository,
            Clock clock,
            FileStorageService fileStorageService,
            AiAnalysisClient aiAnalysisClient,
            GeminiInspectionReportService geminiInspectionReportService,
            PlatformTransactionManager transactionManager,
            SubscriptionService subscriptionService
    ) {
        this.inspectionRepository =
                inspectionRepository;

        this.vehicleRepository =
                vehicleRepository;

        this.businessContextService = businessContextService;
        this.inspectionAccessService = inspectionAccessService;
        this.businessAccountRepository = businessAccountRepository;
        this.userRepository = userRepository;
        this.clock = clock;

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

        this.subscriptionService =
                subscriptionService;
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
            Double latitude,
            Double longitude,
            String authenticatedEmail
    ) {
        User user =
                businessContextService.requireUser(
                        authenticatedEmail
                );

        Vehicle vehicle =
                findAccessibleVehicle(
                        vehicleId,
                        user
                );

        if (city == null || city.isBlank()) {
            throw new IllegalArgumentException(
                    "Şehir bilgisi zorunludur."
            );
        }

        if (latitude == null
                || latitude < -90
                || latitude > 90) {

            throw new IllegalArgumentException(
                    "Geçerli bir enlem bilgisi zorunludur."
            );
        }

        if (longitude == null
                || longitude < -180
                || longitude > 180) {

            throw new IllegalArgumentException(
                    "Geçerli bir boylam bilgisi zorunludur."
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

        inspection.setLocationLatitude(
                latitude
        );

        inspection.setLocationLongitude(
                longitude
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
                businessContextService.requireUser(
                        authenticatedEmail
                );

        List<DamageInspection> inspections = businessContextService.findMembership(user)
                .map(member -> inspectionRepository
                        .findAllByVehicleBusinessAccountIdOrderByCreatedAtDesc(
                                member.getBusinessAccount().getId()))
                .orElseGet(() -> inspectionRepository
                        .findAllByVehicleUserIdAndVehicleBusinessAccountIsNullOrderByCreatedAtDesc(
                                user.getId()));

        return inspections.stream()
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
                businessContextService.requireUser(
                        authenticatedEmail
                );

        DamageInspection inspection =
                inspectionAccessService.requireInspection(
                        inspectionId,
                        user
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
                businessContextService.requireUser(
                        authenticatedEmail
                );

        DamageInspection inspection =
                inspectionAccessService.requireInspection(
                        inspectionId,
                        user
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
                businessContextService.requireUser(
                        authenticatedEmail
                );

        DamageInspection inspection =
                inspectionAccessService.requireInspectionForUpdate(
                        inspectionId,
                        user
                );

        validateNotProcessing(inspection);
        if (inspection.getAnalysisStartedAt() != null) {
            throw new IllegalStateException(
                    "Analizi başlamış incelemenin fotoğrafı değiştirilemez. Yeni bir inceleme oluşturun.");
        }

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
        inspection.setAnalysisStartedAt(null);
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
        ImageValidationContext imageValidation =
                validateInspectionImageInternal(
                        inspectionId,
                        authenticatedEmail
                );
        if (!imageValidation.quality().suitable()) {
            throw new UnsuitableInspectionImageException(
                    imageValidation.quality().message()
            );
        }

        AnalysisContext context =
                transactionTemplate.execute(
                        status -> {

                            User user =
                                    businessContextService.requireUser(
                                            authenticatedEmail
                                    );

                            DamageInspection inspection =
                                    inspectionAccessService.requireInspectionForUpdate(
                                            inspectionId,
                                            user
                                    );

                            validateImageExists(
                                    inspection
                            );

                            if (!Objects.equals(
                                    inspection.getImagePath(),
                                    imageValidation.imagePath()
                            )) {
                                throw new IllegalStateException(
                                        "Fotoğraf değiştirildi. Lütfen analizi tekrar başlatın."
                                );
                            }

                            validateNotProcessing(inspection);
                            validateAnalysisLimit(inspection, user);

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
                                    user,
                                    inspection.getImagePath()
                            );
                        }
                );

        if (context == null) {
            throw new IllegalStateException(
                    "Analiz başlatılamadı."
            );
        }

        try {
            Path storedImagePath =
                    fileStorageService
                            .resolveStoredFile(
                                    context.imagePath()
                            );

            AiAnalysisResponse aiResponse =
                    aiAnalysisClient.analyze(
                            storedImagePath
                    );

            normalizeAndValidateAnalysisResponse(aiResponse);

            return persistAnalysisResult(
                    context,
                    aiResponse
            );

        } catch (RuntimeException exception) {

            return markAnalysisAsFailed(
                    context,
                    exception
            );
        }
    }

    public ImageQualityResponse validateInspectionImage(
            Long inspectionId,
            String authenticatedEmail
    ) {
        return validateInspectionImageInternal(
                inspectionId,
                authenticatedEmail
        ).quality();
    }

    private ImageValidationContext validateInspectionImageInternal(
            Long inspectionId,
            String authenticatedEmail
    ) {
        ImageValidationContext context = transactionTemplate.execute(
                status -> {
                    User user = businessContextService.requireUser(
                            authenticatedEmail
                    );
                    DamageInspection inspection =
                            inspectionAccessService.requireInspection(
                                    inspectionId,
                                    user
                            );
                    validateImageExists(inspection);
                    validateNotProcessing(inspection);
                    if (inspection.getStatus() == InspectionStatus.COMPLETED) {
                        throw new IllegalStateException(
                                "Bu inceleme tamamlandı. Yeni fotoğraf analizi için yeni bir inceleme oluşturun."
                        );
                    }
                    return new ImageValidationContext(
                            inspection.getId(),
                            user,
                            inspection.getImagePath(),
                            null
                    );
                }
        );

        if (context == null) {
            throw new IllegalStateException(
                    "Fotoğraf uygunluğu kontrol edilemedi."
            );
        }

        ImageQualityResponse quality;
        try {
            Path storedImagePath = fileStorageService.resolveStoredFile(
                    context.imagePath()
            );
            quality = aiAnalysisClient.validateImage(
                    storedImagePath
            );
            if (quality == null
                    || quality.code() == null
                    || quality.message() == null) {
                throw new AiServiceException(
                        "AI servisi geçerli bir fotoğraf uygunluk sonucu döndürmedi."
                );
            }
        } catch (RuntimeException exception) {
            markAnalysisAsFailed(
                    new AnalysisContext(
                            context.inspectionId(),
                            context.user(),
                            context.imagePath()
                    ),
                    exception
            );
            throw exception;
        }
        return new ImageValidationContext(
                context.inspectionId(),
                context.user(),
                context.imagePath(),
                quality
        );
    }

    private void normalizeAndValidateAnalysisResponse(
            AiAnalysisResponse response
    ) {
        if (response == null || response.getDamageSeverity() == null
                || response.getDamageSeverity() == DamageSeverity.UNKNOWN) {
            throw new AiServiceException(
                    "AI servisi geçerli bir hasar sonucu döndürmedi."
            );
        }

        if (response.getDamageSeverity() == DamageSeverity.NONE) {
            boolean hasDetections = response.getDetections() != null
                    && !response.getDetections().isEmpty();
            boolean hasVisibleDamageType = response.getDamageTypes() != null
                    && response.getDamageTypes().stream().anyMatch(
                    type -> type != null
                            && type != DamageType.NO_VISIBLE_DAMAGE);
            boolean hasVisibleDamageRecommendation =
                    response.getRepairRecommendations() != null
                    && response.getRepairRecommendations().stream().anyMatch(
                    item -> item != null
                            && item.getDamageType() != null
                            && item.getDamageType() != DamageType.NO_VISIBLE_DAMAGE);
            if (hasDetections || hasVisibleDamageType
                    || hasVisibleDamageRecommendation) {
                throw new AiServiceException(
                        "AI servisi birbiriyle çelişen analiz verisi döndürdü."
                );
            }

            RepairRecommendationResponse recommendation =
                    new RepairRecommendationResponse();
            recommendation.setDamageType(DamageType.NO_VISIBLE_DAMAGE);
            recommendation.setRecommendedAction(RepairAction.NO_ACTION);
            recommendation.setPartReplacementRequired(false);
            recommendation.setAffectedParts(List.of());

            response.setDamageTypes(List.of(DamageType.NO_VISIBLE_DAMAGE));
            response.setAffectedParts(List.of());
            response.setDetections(List.of());
            response.setRepairRecommendations(List.of(recommendation));
            response.setConfidenceScore(0.0);
            response.setAnalysisMessage(
                    "Gönderilen görüntüde görünür hasar tespit edilmedi. "
                            + "Bu sonuç yalnızca görüntüdeki görünür hasar analizidir; "
                            + "mekanik veya profesyonel ekspertiz garantisi değildir."
            );
            return;
        }

        Double confidence = response.getConfidenceScore();
        if (confidence == null || !Double.isFinite(confidence)
                || confidence < 0.0 || confidence > 1.0
                || response.getRepairRecommendations() == null
                || response.getRepairRecommendations().stream().noneMatch(
                item -> item != null
                        && item.getDamageType() != null
                        && item.getDamageType() != DamageType.NO_VISIBLE_DAMAGE
                        && item.getRecommendedAction() != null
                        && item.getRecommendedAction() != RepairAction.NO_ACTION)) {
            throw new AiServiceException(
                    "AI servisi eksik veya geçersiz analiz verisi döndürdü."
            );
        }
    }

    private DamageInspectionResponse persistAnalysisResult(
            AnalysisContext context,
            AiAnalysisResponse aiResponse
    ) {
        transactionTemplate.executeWithoutResult(
                status -> {

                    DamageInspection inspection =
                            inspectionAccessService.requireInspection(
                                    context.inspectionId(),
                                    context.user()
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
                            LocalDateTime.now(clock)
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
                                    inspectionAccessService.requireInspection(
                                            context.inspectionId(),
                                            context.user()
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
                                    inspectionAccessService.requireInspection(
                                            context.inspectionId(),
                                            context.user()
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
                    context.user()
            );

            return;
        }

        try {
            LlmInspectionReportResult result =
                    request.damageSeverity() == DamageSeverity.NONE
                            ? buildNoVisibleDamageReport()
                            : geminiInspectionReportService.generateReport(request);

            saveGeneratedReport(
                    context.inspectionId(),
                    context.user(),
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
                    context.user()
            );
        }
    }

    private LlmInspectionReportResult buildNoVisibleDamageReport() {
        LlmInspectionReportResult result = new LlmInspectionReportResult();
        result.title = "Görünür Hasar Tespit Edilmedi";
        result.summary = "Gönderilen görüntüde görünür bir hasar tespit edilmedi.";
        result.damageDescription =
                "AI analizi, gönderilen fotoğrafta görünür bir hasar işareti bulmadı.";
        result.repairRecommendation =
                "Görüntüdeki görünür hasar açısından bir onarım işlemi önerilmiyor.";
        result.estimatedMinimumPrice = BigDecimal.ZERO;
        result.estimatedMaximumPrice = BigDecimal.ZERO;
        result.currency = "TRY";
        result.priceInformation =
                "Görünür hasar tespit edilmediği için onarım maliyeti hesaplanmadı.";
        result.priceSourceDescription =
                "Sonuç, yalnızca gönderilen görüntünün AI analizine dayanır.";
        result.disclaimer =
                "Bu sonuç yalnızca gönderilen görüntüde görünür hasar tespit "
                        + "edilmediğini belirtir; mekanik veya profesyonel ekspertiz "
                        + "garantisi değildir.";
        return result;
    }

    private void saveGeneratedReport(
            Long inspectionId,
            User user,
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
                            inspectionAccessService.requireInspection(
                                    inspectionId,
                                    user
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
            User user
    ) {
        transactionTemplate.executeWithoutResult(
                status -> {

                    DamageInspection inspection =
                            inspectionAccessService.requireInspection(
                                    inspectionId,
                                    user
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
                                    inspectionAccessService.requireInspection(
                                            context.inspectionId(),
                                            context.user()
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
        if ((exception instanceof IllegalStateException
                || exception instanceof AiServiceException)
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
                                    businessContextService.requireUser(
                                            authenticatedEmail
                                    );

                            DamageInspection inspection =
                                    inspectionAccessService.requireInspectionForUpdate(
                                            inspectionId,
                                            user
                                    );

                            validateNotProcessing(inspection);

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
                                    user,
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
                    context.request().damageSeverity() == DamageSeverity.NONE
                            ? buildNoVisibleDamageReport()
                            : geminiInspectionReportService.generateReport(
                                    context.request()
                            );

            saveGeneratedReport(
                    context.inspectionId(),
                    context.user(),
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
                    context.user()
            );
        }

        DamageInspectionResponse response =
                transactionTemplate.execute(
                        status -> {

                            DamageInspection inspection =
                                    inspectionAccessService.requireInspection(
                                            context.inspectionId(),
                                            context.user()
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

    private Vehicle findAccessibleVehicle(Long vehicleId, User user) {
        if (businessContextService.findMembership(user).isPresent()) {
            BusinessAccount businessAccount =
                    businessContextService.requireBusinessAccount(user);
            return vehicleRepository.findByIdAndBusinessAccountIdAndArchivedFalse(
                            vehicleId,
                            businessAccount.getId()
                    )
                    .orElseThrow(() -> new ResourceNotFoundException(
                            "Araç bulunamadı. ID: " + vehicleId));
        }

        return vehicleRepository.findByIdAndUserIdAndArchivedFalse(vehicleId, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Araç bulunamadı. ID: " + vehicleId));
    }

    private void validateNotProcessing(DamageInspection inspection) {
        if (inspection.getStatus() == InspectionStatus.PROCESSING
                || inspection.getReportStatus() == ReportStatus.PROCESSING) {
            throw new IllegalStateException("İnceleme şu anda işleniyor. Lütfen tamamlanmasını bekleyin.");
        }
    }

    private void validateAnalysisLimit(DamageInspection inspection, User user) {
        if (inspection.getStatus() == InspectionStatus.COMPLETED) {
            throw new IllegalStateException(
                    "Bu inceleme tamamlandı. Yeni fotoğraf analizi için yeni bir inceleme oluşturun.");
        }

        LocalDateTime startedAt = LocalDateTime.now(clock);
        LocalDateTime previousStart = inspection.getAnalysisStartedAt();
        boolean alreadyCountedThisMonth = previousStart != null
                && previousStart.getYear() == startedAt.getYear()
                && previousStart.getMonth() == startedAt.getMonth();

        if (alreadyCountedThisMonth) {
            return;
        }

        BusinessAccount businessAccount = inspection.getVehicle().getBusinessAccount();
        if (businessAccount == null) {
            User lockedUser = userRepository.findByIdForUpdate(user.getId())
                    .orElseThrow(() -> new ResourceNotFoundException("Kullanıcı bulunamadı."));
            subscriptionService.validatePersonalMonthlyAnalysisLimit(lockedUser, startedAt);
            inspection.setAnalysisStartedAt(startedAt);
            return;
        }

        BusinessAccount activeBusinessAccount =
                businessContextService.requireBusinessAccount(user);

        if (!activeBusinessAccount.getId().equals(businessAccount.getId())) {
            throw new ResourceNotFoundException("Şirket aracı bulunamadı.");
        }

        // Serialize count and reservation across every member of the company.
        businessAccountRepository.findByIdForUpdate(businessAccount.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Şirket bulunamadı."));
        subscriptionService.validateBusinessMonthlyAnalysisLimit(businessAccount, startedAt);
        inspection.setAnalysisStartedAt(startedAt);
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
            User user,
            String imagePath
    ) {
    }

    private record ImageValidationContext(
            Long inspectionId,
            User user,
            String imagePath,
            ImageQualityResponse quality
    ) {
    }

    private record ReportGenerationContext(
            Long inspectionId,
            User user,
            InspectionLlmRequest request
    ) {
    }
}
