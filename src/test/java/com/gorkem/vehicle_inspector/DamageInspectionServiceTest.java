
package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.client.AiAnalysisClient;
import com.gorkem.vehicle_inspector.dto.llm.LlmInspectionReportResult;
import com.gorkem.vehicle_inspector.dto.response.AiAnalysisResponse;
import com.gorkem.vehicle_inspector.dto.response.ImageQualityResponse;
import com.gorkem.vehicle_inspector.dto.response.RepairRecommendationResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.exception.UnsuitableInspectionImageException;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import com.gorkem.vehicle_inspector.service.report.GeminiInspectionReportService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.nio.file.Path;
import java.time.*;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DamageInspectionServiceTest {
    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-09-15T10:00:00Z"), ZoneId.of("Europe/Istanbul"));
    private static final LocalDateTime NOW = LocalDateTime.now(CLOCK);

    @Mock private DamageInspectionRepository inspections;
    @Mock private VehicleRepository vehicles;
    @Mock private BusinessAccountRepository businesses;
    @Mock private UserRepository users;
    @Mock private BusinessContextService context;
    @Mock private FileStorageService storage;
    @Mock private AiAnalysisClient ai;
    @Mock private GeminiInspectionReportService reports;
    @Mock private PlatformTransactionManager transactions;
    @Mock private AnalysisUsageRepository analysisUsageRepository;

    private DamageInspectionService service;
    private User creator;
    private User actor;
    private BusinessAccount business;
    private Vehicle vehicle;
    private DamageInspection inspection;

    @BeforeEach
    void setUp() {
        creator = user(1L);
        actor = user(2L);
        business = new BusinessAccount("Test Company");
        ReflectionTestUtils.setField(business, "id", 10L);
        vehicle = new Vehicle("35TEST01", "Test", "Car", 2022, 1000, business);
        ReflectionTestUtils.setField(vehicle, "id", 20L);
        inspection = new DamageInspection(vehicle, creator, InspectionStatus.PENDING);
        ReflectionTestUtils.setField(inspection, "id", 30L);
        inspection.setImagePath("image.jpg");
        inspection.setLocationCity("İzmir");
        inspection.setLocationLatitude(38.4);
        inspection.setLocationLongitude(27.1);
        inspection.setReportStatus(ReportStatus.PENDING);

        lenient().when(context.requireUser(actor.getEmail())).thenReturn(actor);
        lenient().when(context.findMembership(actor)).thenReturn(Optional.of(
                new BusinessMember(business, actor, BusinessRole.MEMBER)));
        lenient().when(context.requireBusinessAccount(actor)).thenReturn(business);
        lenient().when(inspections.findById(30L)).thenReturn(Optional.of(inspection));
        lenient().when(inspections.findByIdForUpdate(30L)).thenReturn(Optional.of(inspection));
        lenient().when(inspections.save(any())).thenAnswer(call -> call.getArgument(0));
        lenient().when(businesses.findByIdForUpdate(10L)).thenReturn(Optional.of(business));
        lenient().when(transactions.getTransaction(any())).thenAnswer(call -> new SimpleTransactionStatus());

        lenient().when(users.findByIdForUpdate(actor.getId())).thenReturn(Optional.of(actor));
        lenient().when(storage.resolveStoredFile("image.jpg")).thenReturn(Path.of("image.jpg"));
        lenient().when(ai.validateImage(any())).thenReturn(
                new ImageQualityResponse(true, "SUITABLE", "Fotoğraf analiz için uygun."));

        service = new DamageInspectionService(inspections, vehicles, context,
                new InspectionAccessService(inspections, context), businesses, users, CLOCK,
                storage, ai, reports, transactions,
                new SubscriptionService(
                        analysisUsageRepository,
                        vehicles,
                        CLOCK
                ));
    }

    @ParameterizedTest
    @EnumSource(SubscriptionPlan.class)
    void memberUsesSharedQuotaRegardlessOfPersonalPlanAndPreservesCreator(SubscriptionPlan plan) {
        actor.setSubscriptionPlan(plan);
        when(
                analysisUsageRepository
                        .countByBusinessAccount_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                                10L,
                                NOW.toLocalDate().withDayOfMonth(1).atStartOfDay(),
                                NOW.toLocalDate().withDayOfMonth(1).plusMonths(1).atStartOfDay()
                        )
        ).thenReturn(99L);
        successfulAnalysis();

        var result = service.analyzeInspection(30L, actor.getEmail());

        assertEquals(InspectionStatus.COMPLETED, result.getStatus());
        assertEquals(ReportStatus.COMPLETED, result.getReportStatus());
        assertEquals(creator.getId(), result.getUserId());
        assertSame(creator, inspection.getUser());
        assertEquals(NOW, inspection.getAnalysisStartedAt());
        verify(
                analysisUsageRepository,
                never()
        ).countByUser_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                any(),
                any(),
                any()
        );
        verify(businesses).findByIdForUpdate(10L);
    }

    @Test
    void hundredCompanyAnalysesBlockBeforeExternalCallsOrReservation() {
        when(
                analysisUsageRepository
                        .countByBusinessAccount_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                                eq(10L),
                                any(LocalDateTime.class),
                                any(LocalDateTime.class)
                        )
        ).thenReturn(100L);

        assertThrows(IllegalStateException.class, () -> service.analyzeInspection(30L, actor.getEmail()));

        assertNull(inspection.getAnalysisStartedAt());
        assertEquals(InspectionStatus.PENDING, inspection.getStatus());
        verify(inspections, never()).save(any());
        verify(ai).validateImage(Path.of("image.jpg"));
        verify(ai, never()).analyze(any());
        verifyNoInteractions(reports);
    }

    @Test
    void memberCanCreateInspectionForCompanyVehicleWithCreatorAudit() {
        when(vehicles.findByIdAndBusinessAccountIdAndArchivedFalse(20L, 10L))
                .thenReturn(Optional.of(vehicle));

        var result = service.createInspection(20L, " İzmir ", 38.4, 27.1, actor.getEmail());

        assertEquals(actor.getId(), result.getUserId());
        assertEquals(20L, result.getVehicleId());
        verify(vehicles, never()).findByIdAndUserIdAndArchivedFalse(any(), any());
        verifyNoInteractions(analysisUsageRepository);
    }

    @Test
    void memberCannotCreateInspectionForPersonalOrOtherCompanyVehicle() {
        when(vehicles.findByIdAndBusinessAccountIdAndArchivedFalse(99L, 10L))
                .thenReturn(Optional.empty());
        assertThrows(ResourceNotFoundException.class,
                () -> service.createInspection(99L, "İzmir", 38.4, 27.1, actor.getEmail()));
        verify(inspections, never()).save(any());
        verify(vehicles, never()).findByIdAndUserIdAndArchivedFalse(any(), any());
    }

    @Test
    void companyHistoryIncludesOtherCreatorsAndArchivedVehicles() {
        vehicle.setArchived(true);
        when(inspections.findAllByVehicleBusinessAccountIdOrderByCreatedAtDesc(10L))
                .thenReturn(List.of(inspection));

        assertEquals(creator.getId(), service.getMyInspections(actor.getEmail()).getFirst().getUserId());
        assertEquals(creator.getId(), service.getMyInspectionById(30L, actor.getEmail()).getUserId());
        verify(inspections, never())
                .findAllByVehicleUserIdAndVehicleBusinessAccountIsNullOrderByCreatedAtDesc(any());
    }

    @Test
    void personalHistoryUsesVehicleOwnership() {
        when(context.findMembership(actor)).thenReturn(Optional.empty());
        when(inspections.findAllByVehicleUserIdAndVehicleBusinessAccountIsNullOrderByCreatedAtDesc(actor.getId()))
                .thenReturn(List.of());
        assertTrue(service.getMyInspections(actor.getEmail()).isEmpty());
        verify(inspections, never()).findAllByVehicleBusinessAccountIdOrderByCreatedAtDesc(any());
    }

    @Test
    void outsiderCannotReadAnalyzeUploadOrRegenerateCompanyInspectionEvenIfCreator() {
        when(context.findMembership(actor)).thenReturn(Optional.empty());
        inspection.setUser(actor);
        assertThrows(ResourceNotFoundException.class, () -> service.getMyInspectionById(30L, actor.getEmail()));
        assertThrows(ResourceNotFoundException.class, () -> service.getInspectionImage(30L, actor.getEmail()));
        assertThrows(ResourceNotFoundException.class, () -> service.analyzeInspection(30L, actor.getEmail()));
        assertThrows(ResourceNotFoundException.class, () -> service.uploadInspectionImage(30L, image(), actor.getEmail()));
        assertThrows(ResourceNotFoundException.class, () -> service.regenerateReport(30L, actor.getEmail()));
        verifyNoInteractions(ai, reports, storage, businesses);
        verifyNoInteractions(analysisUsageRepository);
    }

    @Test
    void memberCannotReadOwnPersonalInspection() {
        vehicle.assignToUser(actor);
        inspection.setUser(actor);
        assertThrows(ResourceNotFoundException.class, () -> service.getMyInspectionById(30L, actor.getEmail()));
    }

    @Test
    void memberCannotReadAnotherCompanyInspection() {
        BusinessAccount other = new BusinessAccount("Other");
        ReflectionTestUtils.setField(other, "id", 11L);
        vehicle.assignToBusiness(other);
        assertThrows(ResourceNotFoundException.class, () -> service.getMyInspectionById(30L, actor.getEmail()));
    }

    @Test
    void personalAnalysisKeepsPersonalQuota() {
        when(context.findMembership(actor)).thenReturn(Optional.empty());
        vehicle.assignToUser(actor);
        successfulAnalysis();

        assertEquals(InspectionStatus.COMPLETED, service.analyzeInspection(30L, actor.getEmail()).getStatus());
        verify(analysisUsageRepository)
                .countByUser_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                        eq(actor.getId()),
                        any(LocalDateTime.class),
                        any(LocalDateTime.class)
                );
        verify(analysisUsageRepository)
                .save(any(AnalysisUsage.class));
        verifyNoInteractions(businesses);
    }

    @Test
    void missingImageDoesNotConsumeQuota() {
        inspection.setImagePath(null);
        assertThrows(IllegalStateException.class, () -> service.analyzeInspection(30L, actor.getEmail()));
        verifyNoInteractions(businesses, ai);
        verifyNoInteractions(analysisUsageRepository);
    }

    @Test
    void failedAnalysisRetainsReservationAndSameMonthRetryDoesNotConsumeAnotherSlot() {
        when(storage.resolveStoredFile("image.jpg")).thenReturn(Path.of("image.jpg"));
        when(ai.analyze(any())).thenThrow(new IllegalStateException("AI unavailable"));
        assertEquals(InspectionStatus.FAILED, service.analyzeInspection(30L, actor.getEmail()).getStatus());
        assertEquals(NOW, inspection.getAnalysisStartedAt());

        service.analyzeInspection(30L, actor.getEmail());

        verify(analysisUsageRepository, times(1))
                .countByBusinessAccount_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                        eq(10L),
                        any(LocalDateTime.class),
                        any(LocalDateTime.class)
                );
        verify(analysisUsageRepository, times(1))
                .save(any(AnalysisUsage.class));
        verify(ai, times(2)).analyze(any());
    }

    @Test
    void previousMonthFailedInspectionNeedsCurrentMonthQuota() {
        inspection.setAnalysisStartedAt(NOW.minusMonths(1));
        inspection.setStatus(InspectionStatus.FAILED);
        when(
                analysisUsageRepository
                        .countByBusinessAccount_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                                eq(10L),
                                any(LocalDateTime.class),
                                any(LocalDateTime.class)
                        )
        ).thenReturn(100L);
        assertThrows(IllegalStateException.class, () -> service.analyzeInspection(30L, actor.getEmail()));
        assertEquals(NOW.minusMonths(1), inspection.getAnalysisStartedAt());
        verify(ai).validateImage(Path.of("image.jpg"));
        verify(ai, never()).analyze(any());
    }

    @Test
    void companyPhotoCannotBeReplacedAfterAnalysisStarts() {
        inspection.setAnalysisStartedAt(NOW);
        assertThrows(IllegalStateException.class,
                () -> service.uploadInspectionImage(30L, image(), actor.getEmail()));
        assertEquals(NOW, inspection.getAnalysisStartedAt());
        assertEquals("image.jpg", inspection.getImagePath());
        verifyNoInteractions(storage);
    }

    @Test
    void memberCanUploadAndReadPhotoBeforeAnalysisWithoutChangingCreator() {
        when(storage.storeImage(any())).thenReturn("new.jpg");
        TransactionSynchronizationManager.initSynchronization();
        try {
            var response = service.uploadInspectionImage(30L, image(), actor.getEmail());
            assertEquals(creator.getId(), response.getUserId());
            assertEquals("new.jpg", inspection.getImagePath());
            TransactionSynchronizationManager.getSynchronizations().forEach(
                    callback -> callback.afterCompletion(TransactionSynchronization.STATUS_COMMITTED));
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }
        verify(storage).deleteStoredFile("image.jpg");
        when(storage.resolveStoredFile("new.jpg")).thenReturn(Path.of("new.jpg"));
        assertEquals(Path.of("new.jpg"), service.getInspectionImage(30L, actor.getEmail()));
    }

    @Test
    void processingInspectionRejectsConcurrentMutation() {
        inspection.setStatus(InspectionStatus.PROCESSING);
        assertThrows(IllegalStateException.class, () -> service.analyzeInspection(30L, actor.getEmail()));
        assertThrows(IllegalStateException.class, () -> service.uploadInspectionImage(30L, image(), actor.getEmail()));
        assertThrows(IllegalStateException.class, () -> service.regenerateReport(30L, actor.getEmail()));
        verifyNoInteractions(ai, reports, storage, businesses);
    }

    @Test
    void completedCompanyInspectionCannotRerunYoloButCanRegenerateReport() {
        inspection.setStatus(InspectionStatus.COMPLETED);
        inspection.setDamageSeverity(DamageSeverity.NONE);
        inspection.setAnalysisStartedAt(NOW);
        assertThrows(IllegalStateException.class, () -> service.analyzeInspection(30L, actor.getEmail()));

        var result = service.regenerateReport(30L, actor.getEmail());

        assertEquals(ReportStatus.COMPLETED, result.getReportStatus());
        assertEquals("Görünür Hasar Tespit Edilmedi", result.getReport().title());
        assertEquals(creator.getId(), result.getUserId());
        assertEquals(NOW, inspection.getAnalysisStartedAt());
        verifyNoInteractions(ai, reports, businesses);
        verifyNoInteractions(analysisUsageRepository);
    }

    @Test
    void reportFailureKeepsCompletedAnalysisAndCreator() {
        when(storage.resolveStoredFile("image.jpg")).thenReturn(Path.of("image.jpg"));
        AiAnalysisResponse response = minorAnalysisResponse();
        when(ai.analyze(any())).thenReturn(response);
        when(reports.generateReport(any())).thenThrow(new IllegalStateException("Gemini unavailable"));

        var result = service.analyzeInspection(30L, actor.getEmail());

        assertEquals(InspectionStatus.COMPLETED, result.getStatus());
        assertEquals(ReportStatus.FAILED, result.getReportStatus());
        assertEquals(creator.getId(), result.getUserId());
    }

    @Test
    void noVisibleDamageCompletesWithCanonicalResultConsumesQuotaAndSkipsGemini() {
        when(storage.resolveStoredFile("image.jpg")).thenReturn(Path.of("image.jpg"));
        AiAnalysisResponse response = new AiAnalysisResponse();
        response.setDamageSeverity(DamageSeverity.NONE);
        when(ai.analyze(any())).thenReturn(response);

        var result = service.analyzeInspection(30L, actor.getEmail());

        assertEquals(InspectionStatus.COMPLETED, result.getStatus());
        assertEquals(DamageSeverity.NONE, result.getDamageSeverity());
        assertEquals(List.of(DamageType.NO_VISIBLE_DAMAGE), result.getDamageTypes());
        assertEquals(1, result.getRepairRecommendations().size());
        assertEquals(RepairAction.NO_ACTION,
                result.getRepairRecommendations().getFirst().recommendedAction());
        assertEquals(ReportStatus.COMPLETED, result.getReportStatus());
        assertEquals("Görünür Hasar Tespit Edilmedi", result.getReport().title());
        assertTrue(result.getReport().disclaimer().contains("profesyonel ekspertiz garantisi değildir"));
        assertEquals(NOW, inspection.getAnalysisStartedAt());
        verify(analysisUsageRepository)
                .countByBusinessAccount_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                        eq(10L),
                        any(LocalDateTime.class),
                        any(LocalDateTime.class)
                );
        verify(analysisUsageRepository)
                .save(any(AnalysisUsage.class));
        verifyNoInteractions(reports);
    }

    @Test
    void validMinorDamageRemainsMinorAndUsesGeminiReport() {
        when(storage.resolveStoredFile("image.jpg")).thenReturn(Path.of("image.jpg"));
        when(ai.analyze(any())).thenReturn(minorAnalysisResponse());
        when(reports.generateReport(any())).thenReturn(report());

        var result = service.analyzeInspection(30L, actor.getEmail());

        assertEquals(InspectionStatus.COMPLETED, result.getStatus());
        assertEquals(DamageSeverity.MINOR, result.getDamageSeverity());
        assertEquals(List.of(DamageType.SCRATCH), result.getDamageTypes());
        assertEquals(RepairAction.PAINT_TOUCH_UP,
                result.getRepairRecommendations().getFirst().recommendedAction());
        verify(reports).generateReport(any());
    }

    @Test
    void invalidAiResponseIsTechnicalFailureAndKeepsQuotaReservationForRetry() {
        when(storage.resolveStoredFile("image.jpg")).thenReturn(Path.of("image.jpg"));
        when(ai.analyze(any())).thenReturn(new AiAnalysisResponse());

        var result = service.analyzeInspection(30L, actor.getEmail());

        assertEquals(InspectionStatus.FAILED, result.getStatus());
        assertEquals(NOW, inspection.getAnalysisStartedAt());
        assertTrue(result.getAnalysisMessage().contains("geçerli bir hasar sonucu"));
        verifyNoInteractions(reports);
    }

    @Test
    void noneSeverityCannotHideARealMinorDamageSignal() {
        when(storage.resolveStoredFile("image.jpg")).thenReturn(Path.of("image.jpg"));
        AiAnalysisResponse response = minorAnalysisResponse();
        response.setDamageSeverity(DamageSeverity.NONE);
        when(ai.analyze(any())).thenReturn(response);

        var result = service.analyzeInspection(30L, actor.getEmail());

        assertEquals(InspectionStatus.FAILED, result.getStatus());
        assertTrue(result.getAnalysisMessage().contains("çelişen analiz verisi"));
        verifyNoInteractions(reports);
    }

    @Test
    void unsuitableImageDoesNotReserveQuotaOrCreateFailedAnalysis() {
        when(ai.validateImage(any())).thenReturn(new ImageQualityResponse(
                false,
                "TOO_DARK",
                "Fotoğraf çok karanlık. Daha aydınlık bir ortamda tekrar çekin."
        ));

        UnsuitableInspectionImageException exception = assertThrows(
                UnsuitableInspectionImageException.class,
                () -> service.analyzeInspection(30L, actor.getEmail())
        );

        assertTrue(exception.getMessage().contains("çok karanlık"));
        assertEquals(InspectionStatus.PENDING, inspection.getStatus());
        assertNull(inspection.getAnalysisStartedAt());
        verify(ai, never()).analyze(any());
        verifyNoInteractions(analysisUsageRepository);
    }

    @Test
    void technicalQualityValidationFailureIsFailedWithoutReservingQuota() {
        when(ai.validateImage(any())).thenThrow(
                new IllegalStateException("AI quality service unavailable")
        );

        assertThrows(
                IllegalStateException.class,
                () -> service.analyzeInspection(30L, actor.getEmail())
        );

        assertEquals(InspectionStatus.FAILED, inspection.getStatus());
        assertNull(inspection.getAnalysisStartedAt());
        assertTrue(inspection.getAnalysisMessage().contains("unavailable"));
        verify(ai, never()).analyze(any());
        verifyNoInteractions(analysisUsageRepository);
    }

    private void successfulAnalysis() {
        when(storage.resolveStoredFile("image.jpg")).thenReturn(Path.of("image.jpg"));
        AiAnalysisResponse response = new AiAnalysisResponse();
        response.setDamageSeverity(DamageSeverity.NONE);
        when(ai.analyze(any())).thenReturn(response);
    }

    private static AiAnalysisResponse minorAnalysisResponse() {
        RepairRecommendationResponse recommendation = new RepairRecommendationResponse();
        recommendation.setDamageType(DamageType.SCRATCH);
        recommendation.setRecommendedAction(RepairAction.PAINT_TOUCH_UP);
        recommendation.setPartReplacementRequired(false);
        recommendation.setAffectedParts(List.of(VehiclePart.FRONT_BUMPER));

        AiAnalysisResponse response = new AiAnalysisResponse();
        response.setDamageSeverity(DamageSeverity.MINOR);
        response.setConfidenceScore(0.28);
        response.setDamageTypes(List.of(DamageType.SCRATCH));
        response.setAffectedParts(List.of(VehiclePart.FRONT_BUMPER));
        response.setRepairRecommendations(List.of(recommendation));
        return response;
    }

    private static User user(Long id) {
        User user = new User("User " + id, "user" + id + "@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", id);
        return user;
    }

    private static MockMultipartFile image() {
        return new MockMultipartFile("image", "new.jpg", "image/jpeg", new byte[]{1, 2});
    }

    static LlmInspectionReportResult report() {
        LlmInspectionReportResult result = new LlmInspectionReportResult();
        result.title = "Test report";
        result.summary = "No damage";
        result.damageDescription = "No visible damage";
        result.repairRecommendation = "No action needed";
        result.disclaimer = "Estimate";
        return result;
    }
}
