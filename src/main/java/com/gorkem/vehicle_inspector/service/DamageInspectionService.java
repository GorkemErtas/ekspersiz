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
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.data.domain.Pageable;
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
    @Autowired
    private CreditWalletService creditWallets;

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
    private final AnalysisCreditService analysisCreditService;
    private static final int MAX_STORED_INSPECTIONS = 20;

    @Autowired
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
            SubscriptionService subscriptionService,
            AnalysisCreditService analysisCreditService
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
        this.analysisCreditService = analysisCreditService;
    }

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
        this(inspectionRepository, vehicleRepository, businessContextService,
                inspectionAccessService, businessAccountRepository, userRepository,
                clock, fileStorageService, aiAnalysisClient,
                geminiInspectionReportService, transactionManager,
                subscriptionService, null);
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

        List<DamageInspection> inspections = businessContextService.findWorkspaceMembership(user)
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

        String previousContextImagePath =
                inspection.getContextImagePath();
        inspection.setContextImagePath(null);
        registerImageDeletionAfterCommit(
                previousContextImagePath
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

    @Transactional
    public DamageInspectionResponse uploadInspectionContextImage(
            Long inspectionId,
            MultipartFile image,
            String authenticatedEmail
    ) {
        User user = businessContextService.requireUser(authenticatedEmail);
        DamageInspection inspection =
                inspectionAccessService.requireInspectionForUpdate(
                        inspectionId,
                        user
                );

        validateNotProcessing(inspection);
        if (inspection.getAnalysisStartedAt() != null) {
            throw new IllegalStateException(
                    "Analizi başlamış incelemenin fotoğrafı değiştirilemez. Yeni bir inceleme oluşturun."
            );
        }

        String previousImagePath = inspection.getContextImagePath();
        String newImagePath = fileStorageService.storeImage(image);

        registerImageCleanup(previousImagePath, newImagePath);
        inspection.setContextImagePath(newImagePath);

        inspection.setStatus(InspectionStatus.PENDING);
        inspection.setAnalysisMessage(null);
        inspection.setCompletedAt(null);

        return buildResponse(
                inspectionRepository.save(inspection)
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

    private void registerImageDeletionAfterCommit(
            String imagePath
    ) {
        if (imagePath == null || imagePath.isBlank()) {
            return;
        }

        if (!TransactionSynchronizationManager
                .isSynchronizationActive()) {

            throw new IllegalStateException(
                    "Fotoğraf silme işlemi aktif bir transaction gerektiriyor."
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
                                            imagePath
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
        return analyzeInspection(
                inspectionId,
                authenticatedEmail,
                false,
                null
        );
    }

    public DamageInspectionResponse analyzeInspection(
            Long inspectionId,
            String authenticatedEmail,
            boolean requireContextImage
    ) {
        return analyzeInspection(
                inspectionId,
                authenticatedEmail,
                requireContextImage,
                null
        );
    }

    public DamageInspectionResponse analyzeInspection(
            Long inspectionId,
            String authenticatedEmail,
            boolean requireContextImage,
            String vehicleRegion
    ) {
        if (creditWallets == null) {
            aiAnalysisClient.requireAvailable();
            return analyzeWithReservedCredit(inspectionId,authenticatedEmail,true,vehicleRegion,null);
        }
        User user=businessContextService.requireUser(authenticatedEmail);
        DamageInspection initial=inspectionAccessService.requireInspection(inspectionId,user);
        if (initial.getStatus()==InspectionStatus.COMPLETED) {
            return regenerateReport(inspectionId,authenticatedEmail);
        }
        aiAnalysisClient.requireAvailable();
        boolean company=initial.getVehicle().getBusinessAccount()!=null;
        var reservation=creditWallets.reserve(user,company,"ANALYSIS","inspection:"+inspectionId,"inspection:"+inspectionId);
        if (reservation.completed()) return transactionTemplate.execute(status -> buildResponse(inspectionAccessService.requireInspection(inspectionId,user)));
        boolean completed=false;
        try {
            DamageInspectionResponse response=analyzeWithReservedCredit(inspectionId,authenticatedEmail,true,vehicleRegion,reservation.token());
            completed=response.getStatus()==InspectionStatus.COMPLETED && response.getReportStatus()==ReportStatus.COMPLETED;
            return response;
        } finally {
            if (!completed) creditWallets.release(user,reservation.token());
        }
    }

    private DamageInspectionResponse analyzeWithReservedCredit(Long inspectionId,String authenticatedEmail,
            boolean requireContextImage,String vehicleRegion,java.util.UUID creditToken) {
        String normalizedVehicleRegion = normalizeVehicleRegion(vehicleRegion);
        ImageValidationContext imageValidation =
                validateInspectionImageInternal(
                        inspectionId,
                        authenticatedEmail,
                        false
                );
        if (!imageValidation.quality().suitable()) {
            throw new UnsuitableInspectionImageException(
                    imageValidation.quality().message(), imageValidation.quality().code(), false
            );
        }

        User validationUser =
                businessContextService.requireUser(
                        authenticatedEmail
                );
        DamageInspection currentInspection =
                inspectionAccessService.requireInspection(
                        inspectionId,
                        validationUser
                );
        boolean hasContextImage =
                currentInspection.getContextImagePath() != null
                        && !currentInspection.getContextImagePath().isBlank();

        if (requireContextImage && !hasContextImage) {
            throw new IllegalStateException(
                    "Analizden önce geniş açı araç fotoğrafı yüklenmelidir."
            );
        }

        ImageValidationContext contextImageValidation =
                requireContextImage
                        ? validateInspectionImageInternal(
                                inspectionId,
                                authenticatedEmail,
                                true
                        )
                        : null;
        if (contextImageValidation != null
                && !contextImageValidation.quality().suitable()) {
            throw new UnsuitableInspectionImageException(
                    contextImageValidation.quality().message(), contextImageValidation.quality().code(), true
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
                            if (requireContextImage) {
                                validateContextImageExists(
                                        inspection
                                );
                            }

                            if (!Objects.equals(
                                    inspection.getImagePath(),
                                    imageValidation.imagePath()
                            ) || (contextImageValidation != null
                                    && !Objects.equals(
                                            inspection.getContextImagePath(),
                                            contextImageValidation.imagePath()
                                    ))) {
                                throw new IllegalStateException(
                                        "Fotoğraflardan biri değiştirildi. Lütfen analizi tekrar başlatın."
                                );
                            }

                            validateNotProcessing(inspection);
                            if (creditWallets == null && analysisCreditService == null) {
                                validateAnalysisLimit(inspection, user);
                            }
                            if (inspection.getStatus() == InspectionStatus.COMPLETED) {
                                throw new IllegalStateException(
                                        "Bu inceleme tamamlandı. Yeni fotoğraf analizi için yeni bir inceleme oluşturun."
                                );
                            }
                            if (creditToken != null || inspection.getAnalysisStartedAt() == null) {
                                inspection.setAnalysisStartedAt(LocalDateTime.now(clock));
                            }

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
                                    inspection.getImagePath(),
                                    requireContextImage ? inspection.getContextImagePath() : null,
                                    creditToken
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

            Path storedContextImagePath = fileStorageService.resolveStoredFile(context.contextImagePath());
            AiAnalysisResponse aiResponse = aiAnalysisClient.analyze(
                    storedImagePath, storedContextImagePath, normalizedVehicleRegion);

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

    private String normalizeVehicleRegion(String vehicleRegion) {
        if (vehicleRegion == null || vehicleRegion.isBlank()) {
            return null;
        }

        String normalized = vehicleRegion.trim().toUpperCase();
        if (!"FRONT".equals(normalized) && !"REAR".equals(normalized)) {
            throw new IllegalArgumentException(
                    "Araç bölgesi FRONT veya REAR olmalıdır."
            );
        }
        return normalized;
    }

    public ImageQualityResponse validateInspectionImage(
            Long inspectionId,
            String authenticatedEmail
    ) {
        return validateWithCredit(inspectionId,authenticatedEmail,false);
    }

    public ImageQualityResponse validateInspectionContextImage(
            Long inspectionId,
            String authenticatedEmail
    ) {
        return validateWithCredit(inspectionId,authenticatedEmail,true);
    }

    private ImageQualityResponse validateWithCredit(Long inspectionId,String email,boolean contextImage) {
        aiAnalysisClient.requireAvailable();
        if (creditWallets==null) return validateInspectionImageInternal(inspectionId,email,contextImage).quality();
        User user=businessContextService.requireUser(email);
        var inspection=inspectionAccessService.requireInspection(inspectionId,user);
        var reservation=creditWallets.reserve(user,inspection.getVehicle().getBusinessAccount()!=null,"ANALYSIS",
                "validation:"+inspectionId,"validation:"+inspectionId);
        try { return validateInspectionImageInternal(inspectionId,email,contextImage).quality(); }
        finally { creditWallets.release(user,reservation.token()); }
    }

    private ImageValidationContext validateInspectionImageInternal(
            Long inspectionId,
            String authenticatedEmail,
            boolean contextImage
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
                    if (contextImage) {
                        validateContextImageExists(inspection);
                    } else {
                        validateImageExists(inspection);
                    }
                    validateNotProcessing(inspection);
                    if (inspection.getStatus() == InspectionStatus.COMPLETED) {
                        throw new IllegalStateException(
                                "Bu inceleme tamamlandı. Yeni fotoğraf analizi için yeni bir inceleme oluşturun."
                        );
                    }
                    return new ImageValidationContext(
                            inspection.getId(),
                            user,
                            contextImage
                                    ? inspection.getContextImagePath()
                                    : inspection.getImagePath(),
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
                    storedImagePath,
                    contextImage ? "context" : "damage"
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
                            context.imagePath(),
                            null
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

    private void normalizeAndValidateAnalysisResponse(AiAnalysisResponse response) {
        GeminiAnalysisValidator.validate(response);
        if (!"DAMAGE_DETECTED".equals(response.getAnalysisOutcome())) {
            throw new com.gorkem.vehicle_inspector.exception.AdditionalPhotosRequiredException(response);
        }
    }

    private DamageInspectionResponse persistAnalysisResult(
            AnalysisContext context,
            AiAnalysisResponse aiResponse
    ) {
        boolean automaticReport = creditWallets != null || analysisCreditService == null
                || aiResponse.getDamageSeverity() == DamageSeverity.NONE;
        java.util.UUID reportAttempt = transactionTemplate.execute(
                status -> {

                    DamageInspection inspection =
                            inspectionAccessService.requireInspectionForUpdate(
                                    context.inspectionId(),
                                    context.user()
                            );

                    if (context.creditToken()!=null) {
                        creditWallets.assertReservation(context.user(),context.creditToken());
                    }
                    inspection.clearDetections();
                    inspection.clearRepairRecommendations();

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
                    inspection.setAnalysisSchemaVersion(aiResponse.getSchemaVersion());
                    inspection.setAnalysisModelVersion(aiResponse.getModelVersion());
                    if (aiResponse.getSchemaVersion() != null) {
                        try {
                            inspection.setAnalysisPayload(new com.fasterxml.jackson.databind.ObjectMapper()
                                    .writeValueAsString(aiResponse));
                        } catch (com.fasterxml.jackson.core.JsonProcessingException exception) {
                            throw new AiServiceException("Analiz kanıtı kaydedilemedi.", exception);
                        }
                    }


                    inspection.setStatus(
                            InspectionStatus.COMPLETED
                    );

                    inspection.setCompletedAt(
                            LocalDateTime.now(clock)
                    );

                    inspection.setReportStatus(
                            automaticReport ? ReportStatus.PROCESSING : ReportStatus.PENDING
                    );

                    inspection.setReportMessage(
                            automaticReport ? "Hasar tespiti tamamlandı. Detaylı rapor hazırlanıyor."
                                    : "Temel hasar tespiti tamamlandı. Detaylı AI raporunu istediğinizde oluşturabilirsiniz."
                    );

                    java.util.UUID attempt = automaticReport
                            ? inspection.beginReport(LocalDateTime.now(clock)) : null;
                    inspectionRepository.save(
                            inspection
                    );
                    return attempt;
                }
        );


        if (automaticReport) {
            generateReportOutsideTransaction(context, reportAttempt);
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
                    "Analiz sonucu alınamadı."
            );
        }

        return response;
    }

    private void generateReportOutsideTransaction(
            AnalysisContext context,
            java.util.UUID reportAttempt
    ) {
        try {
            InspectionLlmRequest request =
                    transactionTemplate.execute(
                            status -> {

                                DamageInspection inspection =
                                        inspectionAccessService.requireInspection(
                                                context.inspectionId(),
                                                context.user()
                                        );

                                return InspectionLlmMapper.toRequest(inspection);
                            }
                    );

            if (request == null) {

                markReportAsFailed(
                        context.inspectionId(),
                        context.user(), reportAttempt, context.creditToken()
                );

                return;
            }

            LlmInspectionReportResult result =
                    request.damageSeverity() == DamageSeverity.NONE
                            ? buildNoVisibleDamageReport()
                            : geminiInspectionReportService.generateReport(request);

            saveGeneratedReport(
                    context.inspectionId(),
                    context.user(),
                    result,
                    context.creditToken(),
                    reportAttempt
            );

        } catch (RuntimeException exception) {

            log.error(
                    "Gemini report generation failed for inspection {}",
                    context.inspectionId(),
                    exception
            );

            markReportAsFailed(
                    context.inspectionId(),
                    context.user(), reportAttempt, context.creditToken()
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

    private void saveGeneratedReport(Long inspectionId,User user,LlmInspectionReportResult result,
            java.util.UUID creditToken,java.util.UUID reportAttempt) {
        if (result == null) {
            throw new IllegalArgumentException(
                    "Rapor sonucu boş olamaz."
            );
        }

        transactionTemplate.executeWithoutResult(
                status -> {

                    DamageInspection inspection =
                            inspectionAccessService.requireInspectionForUpdate(
                                    inspectionId,
                                    user
                            );

                    if (reportAttempt!=null && !reportAttempt.equals(inspection.getReportAttempt()))
                        throw new IllegalStateException("Rapor isteğinin süresi doldu.");
                    if (creditToken!=null) {
                        creditWallets.complete(user,creditToken);
                        inspection.grantReportAccess(inspection.getVehicle().getBusinessAccount()!=null
                                ? ReportAccessSource.BUSINESS : ReportAccessSource.PURCHASED_CREDIT);
                    }
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

                    pruneOldInspections(
                            inspection
                    );
                }
        );
    }

    private void markReportAsFailed(
            Long inspectionId,
            User user
    ) {
        markReportAsFailed(inspectionId,user,null);
    }

    private void markReportAsFailed(Long inspectionId,User user,java.util.UUID attempt) {
        markReportAsFailed(inspectionId,user,attempt,null);
    }

    private void markReportAsFailed(Long inspectionId,User user,java.util.UUID attempt,java.util.UUID creditToken) {
        transactionTemplate.executeWithoutResult(
                status -> {

                    DamageInspection inspection =
                            inspectionAccessService.requireInspectionForUpdate(
                                    inspectionId,
                                    user
                            );

                    if (attempt!=null && !attempt.equals(inspection.getReportAttempt())) return;
                    // The attempt guard owns this report even if its credit
                    // lease expired; do not leave it stuck in PROCESSING.
                    if (creditToken!=null && attempt==null
                            && !creditWallets.reservationActive(user,creditToken)) return;
                    inspection.setReportStatus(
                            ReportStatus.FAILED
                    );

                    inspection.setReportMessage(
                            "AI raporu şu anda oluşturulamadı."
                    );

                    inspectionRepository.save(
                            inspection
                    );

                    pruneOldInspections(
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
                                    inspectionAccessService.requireInspectionForUpdate(
                                            context.inspectionId(),
                                            context.user()
                                    );

                            // A response/report failure after ML was committed must not
                            // erase successful detections or invite another ML run.
                            if (inspection.getStatus() == InspectionStatus.COMPLETED)
                                return buildResponse(inspection);
                            if (context.creditToken()!=null && !creditWallets.reservationActive(context.user(),context.creditToken()))
                                return buildResponse(inspection);
                            inspection.setStatus(
                                    InspectionStatus.FAILED
                            );

                            inspection.setCompletedAt(
                                    null
                            );
                            if (exception instanceof com.gorkem.vehicle_inspector.exception.AdditionalPhotosRequiredException more) {
                                var evidence = more.getAnalysis();
                                inspection.setDamageSeverity(DamageSeverity.UNKNOWN);
                                inspection.setConfidenceScore(null);
                                inspection.setAnalysisSchemaVersion(evidence.getSchemaVersion());
                                inspection.setAnalysisModelVersion(evidence.getModelVersion());
                                try {
                                    inspection.setAnalysisPayload(new com.fasterxml.jackson.databind.ObjectMapper().writeValueAsString(evidence));
                                } catch (com.fasterxml.jackson.core.JsonProcessingException invalid) {
                                    throw new AiServiceException("Görsel değerlendirme kaydedilemedi.", invalid);
                                }
                            }

                            inspection.setAnalysisMessage(
                                    buildAnalysisErrorMessage(
                                            exception
                                    )
                            );

                            inspection.setReportStatus(
                                    ReportStatus.FAILED
                            );

                            inspection.setReportMessage(
                                    "Görsel analiz tamamlanamadığı için "
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
        if (creditWallets==null) return regenerateReservedReport(inspectionId,authenticatedEmail,null);
        User user=businessContextService.requireUser(authenticatedEmail);
        var initial=inspectionAccessService.requireInspection(inspectionId,user);
        if (initial.isReportAccessGranted() && initial.getReportStatus()==ReportStatus.COMPLETED)
            return transactionTemplate.execute(status -> buildResponse(inspectionAccessService.requireInspection(inspectionId,user)));
        if (initial.isReportAccessGranted()) return regenerateReservedReport(inspectionId,authenticatedEmail,null);
        boolean company=initial.getVehicle().getBusinessAccount()!=null;
        var reservation=creditWallets.reserve(user,company,"ANALYSIS","inspection:"+inspectionId,"inspection:"+inspectionId);
        if (reservation.completed()) return transactionTemplate.execute(status ->
                buildResponse(inspectionAccessService.requireInspection(inspectionId, user)));
        boolean completed=reservation.completed();
        try {
            var response=regenerateReservedReport(inspectionId,authenticatedEmail,reservation.token());
            completed=completed || response.getReportStatus()==ReportStatus.COMPLETED;
            return response;
        } finally { if (!completed) creditWallets.release(user,reservation.token()); }
    }

    private DamageInspectionResponse regenerateReservedReport(Long inspectionId,String authenticatedEmail,java.util.UUID creditToken) {
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
                                        "Rapor oluşturmak için görsel analiz "
                                                + "tamamlanmış olmalıdır."
                                );
                            }

                            if (inspection.getDamageSeverity()
                                    == null) {

                                throw new IllegalStateException(
                                        "İncelemeye ait görsel analiz sonucu "
                                                + "bulunamadı."
                                );
                            }

                            if (creditWallets == null && analysisCreditService != null
                                    && inspection.getDamageSeverity() != DamageSeverity.NONE) {
                                analysisCreditService.grantReportAccess(inspection, user);
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

                            java.util.UUID attempt=inspection.beginReport(LocalDateTime.now(clock));
                            return new ReportGenerationContext(
                                    inspection.getId(),
                                    user,
                                    request,
                                    attempt
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
                    result,
                    creditToken,
                    context.attempt()
            );

        } catch (RuntimeException exception) {

            log.error(
                    "Gemini report regeneration failed for inspection {}",
                    context.inspectionId(),
                    exception
            );

            markReportAsFailed(
                    context.inspectionId(),
                    context.user(),
                    context.attempt()
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

    private void validateContextImageExists(
            DamageInspection inspection
    ) {
        if (inspection.getContextImagePath() == null
                || inspection.getContextImagePath().isBlank()) {
            throw new IllegalStateException(
                    "Analizden önce geniş açı araç fotoğrafı yüklenmelidir."
            );
        }
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
                            response.getPartReplacementRequired(),
                            recommendationParts
                    );

            inspection.addRepairRecommendation(
                    recommendation
            );
        }
    }

    private Vehicle findAccessibleVehicle(Long vehicleId, User user) {
        if (businessContextService.findWorkspaceMembership(user).isPresent()) {
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
                .filter(vehicle -> vehicle.getBusinessAccount() == null)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Araç bulunamadı. ID: " + vehicleId));
    }

    private void validateNotProcessing(DamageInspection inspection) {
        if (creditWallets!=null && inspection.getReportStatus()==ReportStatus.PROCESSING
                && (inspection.getReportStartedAt()==null || inspection.getReportStartedAt().isBefore(LocalDateTime.now(clock).minusMinutes(10)))) {
            inspection.setReportStatus(ReportStatus.FAILED);
        }
        if (creditWallets!=null && inspection.getStatus()==InspectionStatus.PROCESSING
                && inspection.getAnalysisStartedAt()!=null
                && inspection.getAnalysisStartedAt().isBefore(LocalDateTime.now(clock).minusMinutes(10))) {
            inspection.setStatus(InspectionStatus.FAILED);
        }
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
            subscriptionService.validatePersonalMonthlyAnalysisLimit(
                    lockedUser,
                    startedAt
            );

            subscriptionService.recordPersonalAnalysisUsage(
                    lockedUser,
                    startedAt
            );

            inspection.setAnalysisStartedAt(
                    startedAt
            );

            return;
        }

        BusinessAccount activeBusinessAccount =
                businessContextService.requireBusinessAccount(user);

        if (!activeBusinessAccount.getId().equals(businessAccount.getId())) {
            throw new ResourceNotFoundException("Şirket aracı bulunamadı.");
        }

        // Serialize count and reservation across every member of the company.
        BusinessAccount lockedBusinessAccount =
                businessAccountRepository
                        .findByIdForUpdate(
                                businessAccount.getId()
                        )
                        .orElseThrow(
                                () -> new ResourceNotFoundException(
                                        "Şirket bulunamadı."
                                )
                        );

        subscriptionService.validateBusinessMonthlyAnalysisLimit(
                lockedBusinessAccount,
                startedAt
        );

        subscriptionService.recordBusinessAnalysisUsage(
                lockedBusinessAccount,
                startedAt
        );

        inspection.setAnalysisStartedAt(
                startedAt
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
            User user,
            String imagePath,
            String contextImagePath,
            java.util.UUID creditToken
    ) {
        AnalysisContext(Long inspectionId,User user,String imagePath,String contextImagePath) {
            this(inspectionId,user,imagePath,contextImagePath,null);
        }
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
            InspectionLlmRequest request,
            java.util.UUID attempt
    ) {
    }

    private void pruneOldInspections(
            DamageInspection currentInspection
    ) {
        Vehicle vehicle = currentInspection.getVehicle();

        List<DamageInspection> inspections;

        if (vehicle.getBusinessAccount() == null) {
            inspections =
                    inspectionRepository.findPersonalInspectionsForRetention(
                            currentInspection.getUser().getId(),
                            InspectionStatus.PROCESSING,
                            Pageable.unpaged()
                    );
        } else {
            inspections =
                    inspectionRepository.findBusinessInspectionsForRetention(
                            vehicle.getBusinessAccount().getId(),
                            InspectionStatus.PROCESSING,
                            Pageable.unpaged()
                    );
        }

        if (inspections.size() <= MAX_STORED_INSPECTIONS) {
            return;
        }

        List<DamageInspection> obsoleteInspections =
                inspections.subList(
                        MAX_STORED_INSPECTIONS,
                        inspections.size()
                );

        obsoleteInspections.stream()
                .map(DamageInspection::getImagePath)
                .filter(Objects::nonNull)
                .filter(path -> !path.isBlank())
                .forEach(this::registerImageDeletionAfterCommit);

        obsoleteInspections.stream()
                .map(DamageInspection::getContextImagePath)
                .filter(Objects::nonNull)
                .filter(path -> !path.isBlank())
                .forEach(this::registerImageDeletionAfterCommit);

        inspectionRepository.deleteAll(
                obsoleteInspections
        );
    }
}
