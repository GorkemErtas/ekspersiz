package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.client.AiAnalysisClient;
import com.gorkem.vehicle_inspector.client.GooglePlacesClient;
import com.gorkem.vehicle_inspector.dto.llm.NearbyServiceSearchResult;
import com.gorkem.vehicle_inspector.dto.request.RegisterRequest;
import com.gorkem.vehicle_inspector.dto.request.VerifyEmailRequest;
import com.gorkem.vehicle_inspector.dto.response.AiAnalysisResponse;
import com.gorkem.vehicle_inspector.dto.response.ImageQualityResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import com.gorkem.vehicle_inspector.service.report.GeminiInspectionReportService;
import com.gorkem.vehicle_inspector.service.report.GeminiNearbyServiceSearchService;
import jakarta.persistence.EntityManagerFactory;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.context.annotation.*;
import org.springframework.context.support.PropertySourcesPlaceholderConfigurer;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;

import javax.sql.DataSource;
import java.nio.file.Path;
import java.time.*;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Uses only an explicitly supplied disposable PostgreSQL database. */
@EnabledIfSystemProperty(named = "inspection.test.jdbc-url", matches = "jdbc:postgresql:.*")
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class InspectionPersistenceTest {
    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-09-15T10:00:00Z"), ZoneId.of("Europe/Istanbul"));
    private static final LocalDateTime NOW = LocalDateTime.now(CLOCK);
    private static final LocalDateTime START = NOW.toLocalDate().atStartOfDay();

    private AnnotationConfigApplicationContext app;
    private TransactionTemplate tx;
    private JdbcTemplate jdbc;
    private DamageInspectionRepository inspections;
    private VehicleRepository vehicles;
    private UserRepository users;
    private PendingRegistrationRepository pendingRegistrations;
    private BusinessAccountRepository businesses;
    private BusinessMemberRepository members;
    private DamageInspectionService service;
    private SubscriptionService subscriptions;
    private RegistrationService registrationService;
    private AccountDeletionService accountDeletionService;
    private PasswordEncoder passwordEncoder;
    private VerificationCodeService verificationCodes;
    private EmailService emailService;
    private AiAnalysisClient ai;
    private GeminiInspectionReportService reports;
    private FileStorageService storage;
    private User owner;
    private User member;
    private User personal;
    private BusinessAccount business;
    private Vehicle firstVehicle;
    private Vehicle secondVehicle;
    private AnalysisUsageRepository usages;
    private AiAssistantAccessRepository assistantAccesses;
    private AiAssistantDailyUsageRepository assistantDailyUsages;
    private AiAssistantQuotaReservationRepository assistantReservations;

    @BeforeAll
    void startContext() {
        app = new AnnotationConfigApplicationContext(PersistenceConfig.class);
        tx = new TransactionTemplate(app.getBean(PlatformTransactionManager.class));
        jdbc = new JdbcTemplate(app.getBean(DataSource.class));
        inspections = app.getBean(DamageInspectionRepository.class);
        vehicles = app.getBean(VehicleRepository.class);
        users = app.getBean(UserRepository.class);
        pendingRegistrations = app.getBean(PendingRegistrationRepository.class);
        businesses = app.getBean(BusinessAccountRepository.class);
        members = app.getBean(BusinessMemberRepository.class);
        service = app.getBean(DamageInspectionService.class);
        subscriptions = app.getBean(SubscriptionService.class);
        registrationService = app.getBean(RegistrationService.class);
        accountDeletionService = app.getBean(AccountDeletionService.class);
        passwordEncoder = app.getBean(PasswordEncoder.class);
        verificationCodes = app.getBean(VerificationCodeService.class);
        emailService = app.getBean(EmailService.class);
        ai = app.getBean(AiAnalysisClient.class);
        reports = app.getBean(GeminiInspectionReportService.class);
        storage = app.getBean(FileStorageService.class);
        usages = app.getBean(AnalysisUsageRepository.class);
        assistantAccesses = app.getBean(AiAssistantAccessRepository.class);
        assistantDailyUsages = app.getBean(AiAssistantDailyUsageRepository.class);
        assistantReservations = app.getBean(AiAssistantQuotaReservationRepository.class);
    }

    @AfterAll
    void closeContext() {
        if (app != null) {
            app.close();
        }
    }

    @BeforeEach
    void seed() {
        reset(ai, reports, storage, subscriptions, passwordEncoder,
                verificationCodes, emailService,
                app.getBean(GeminiNearbyServiceSearchService.class), app.getBean(GooglePlacesClient.class));
        when(ai.validateImage(any(), anyString())).thenReturn(
                new ImageQualityResponse(true, "SUITABLE", "Fotoğraf analiz için uygun."));
        jdbc.execute("TRUNCATE TABLE pending_registrations, users, business_accounts RESTART IDENTITY CASCADE");
        tx.executeWithoutResult(status -> {
            owner = users.save(new User("Owner", "owner@example.com", "hash"));
            owner.setSubscriptionPlan(SubscriptionPlan.BUSINESS);
            member = users.save(new User("Member", "member@example.com", "hash"));
            personal = users.save(new User("Personal", "personal@example.com", "hash"));
            business = businesses.save(new BusinessAccount("Test Company"));
            members.save(new BusinessMember(business, owner, BusinessRole.OWNER));
            members.save(new BusinessMember(business, member, BusinessRole.MEMBER));
            firstVehicle = vehicles.save(new Vehicle("35TEST01", "Brand", "Model", 2022, 1000, business));
            secondVehicle = vehicles.save(new Vehicle("35TEST02", "Brand", "Model", 2022, 1000, business));
        });
        when(storage.resolveStoredFile(anyString())).thenReturn(Path.of("test.jpg"));
        when(passwordEncoder.encode(anyString()))
                .thenAnswer(call -> "encoded-" + call.getArgument(0));
        when(verificationCodes.generate()).thenReturn("123456");
        when(verificationCodes.hash("123456")).thenReturn("code-hash");
        when(verificationCodes.matches("123456", "code-hash")).thenReturn(true);
        when(ai.analyze(any(), any(), any())).thenAnswer(call -> {
            assertFalse(TransactionSynchronizationManager.isActualTransactionActive());
            return GeminiVisionFixtures.success();
        });
        when(reports.generateReport(any())).thenAnswer(call -> {
            assertFalse(TransactionSynchronizationManager.isActualTransactionActive());
            return DamageInspectionServiceTest.report();
        });
    }

    @Test
    void registrationPersistsUserOnlyAfterSuccessfulVerification() {
        RegisterRequest registration = new RegisterRequest();
        registration.setFullName("Pending User");
        registration.setEmail("pending@example.com");
        registration.setPassword("password");

        registrationService.start(registration);

        assertTrue(users.findByEmail("pending@example.com").isEmpty());
        assertTrue(pendingRegistrations.findByEmail("pending@example.com").isPresent());

        VerifyEmailRequest verification = new VerifyEmailRequest();
        verification.setEmail("pending@example.com");
        verification.setCode("123456");

        registrationService.verify(verification);

        User verifiedUser = users.findByEmail("pending@example.com").orElseThrow();
        assertTrue(verifiedUser.isEmailVerified());
        assertEquals("encoded-password", verifiedUser.getPassword());
        assertTrue(pendingRegistrations.findByEmail("pending@example.com").isEmpty());
    }

    private record BillingFixture(BillingService billing, BusinessAccountService business,
                                  com.gorkem.vehicle_inspector.client.RevenueCatClient provider) {}

    private BillingFixture billingFixture(boolean sandbox) {
        var testers = new com.gorkem.vehicle_inspector.service.billing.BillingSandboxPolicy(sandbox ? personal.getBillingCustomerId() : "");
        var policy = new com.gorkem.vehicle_inspector.service.billing.BusinessBillingPolicy(jdbc,testers,CLOCK);
        var plans = new SubscriptionService(usages,vehicles,CLOCK);
        org.springframework.test.util.ReflectionTestUtils.setField(plans,"businessBilling",policy);
        var provider = mock(com.gorkem.vehicle_inspector.client.RevenueCatClient.class);
        var billing = new BillingService(users,app.getBean(BillingSubscriptionRepository.class),
                app.getBean(BillingWebhookEventRepository.class),plans,provider,
                new com.gorkem.vehicle_inspector.service.billing.RevenueCatWebhookVerifier("verified-hook","",CLOCK),
                new com.fasterxml.jackson.databind.ObjectMapper(),CLOCK);
        org.springframework.test.util.ReflectionTestUtils.setField(billing,"businessBilling",policy);
        org.springframework.test.util.ReflectionTestUtils.setField(billing,"sandboxPolicy",testers);
        org.springframework.test.util.ReflectionTestUtils.setField(billing,"billingJdbc",jdbc);
        var business = new BusinessAccountService(businesses,members,users,plans);
        org.springframework.test.util.ReflectionTestUtils.setField(business,"businessBilling",policy);
        return new BillingFixture(billing,business,provider);
    }

    private com.gorkem.vehicle_inspector.client.RevenueCatCustomer businessReceipt(boolean sandbox) {
        return new com.gorkem.vehicle_inspector.client.RevenueCatCustomer(List.of(
                new com.gorkem.vehicle_inspector.client.RevenueCatSubscription("eksper_business_monthly:monthly",
                        CLOCK.instant(),CLOCK.instant().plusSeconds(3600),null,true,false,false,sandbox,"play_store")),
                List.of(),null,personal.getBillingCustomerId());
    }

    @Test void verifiedSandboxSyncAndConcurrentCompanyConsentCreateOnlyOneIsolatedCompany() throws Exception {
        var fixture = billingFixture(true);
        when(fixture.provider().getCustomer(personal.getBillingCustomerId())).thenReturn(businessReceipt(true));
        var status = tx.execute(s -> fixture.billing().sync(personal.getEmail())).status();
        assertEquals(SubscriptionPlan.BUSINESS,status.currentPlan());
        assertTrue(status.sandbox());
        assertTrue(members.findByUserId(personal.getId()).isEmpty());
        var pool = Executors.newFixedThreadPool(2); var gate = new CountDownLatch(1);
        try {
            List<Future<Boolean>> jobs = new java.util.ArrayList<>();
            for(int i=0;i<2;i++) jobs.add(pool.submit(() -> { gate.await(); try {
                tx.execute(s -> fixture.business().create(personal.getEmail(),
                        new com.gorkem.vehicle_inspector.dto.request.CreateBusinessAccountRequest("Isolated company")));
                return true;
            } catch (IllegalStateException duplicate) { return false; } }));
            gate.countDown(); int created=0;
            for(var job:jobs) if(job.get(10,TimeUnit.SECONDS)) created++;
            assertEquals(1,created);
            assertTrue(members.findByUserId(personal.getId()).orElseThrow().getBusinessAccount().isSandbox());
            assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM business_accounts WHERE company_name='Isolated company'",Integer.class));
        } finally { pool.shutdownNow(); }
    }

    @Test void concurrentSyncCannotResurrectAnOlderReceiptAfterExpiry() throws Exception {
        var fixture = billingFixture(false);
        var firstProvider = new CountDownLatch(1); var releaseProvider = new CountDownLatch(1);
        var secondStarted = new CountDownLatch(1); var calls = new java.util.concurrent.atomic.AtomicInteger();
        when(fixture.provider().getCustomer(personal.getBillingCustomerId())).thenAnswer(i -> {
            if(calls.incrementAndGet()==1) { firstProvider.countDown(); assertTrue(releaseProvider.await(5,TimeUnit.SECONDS)); return businessReceipt(false); }
            return new com.gorkem.vehicle_inspector.client.RevenueCatCustomer(List.of(),List.of(),null);
        });
        var pool=Executors.newFixedThreadPool(2);
        try {
            var first=pool.submit(() -> tx.execute(s -> fixture.billing().sync(personal.getEmail())));
            assertTrue(firstProvider.await(5,TimeUnit.SECONDS));
            var second=pool.submit(() -> { secondStarted.countDown(); return tx.execute(s -> fixture.billing().sync(personal.getEmail())); });
            assertTrue(secondStarted.await(5,TimeUnit.SECONDS));
            assertThrows(TimeoutException.class,() -> second.get(200,TimeUnit.MILLISECONDS));
            assertEquals(1,calls.get());
            releaseProvider.countDown();
            first.get(10,TimeUnit.SECONDS); second.get(10,TimeUnit.SECONDS);
            assertEquals(SubscriptionPlan.FREE,users.findById(personal.getId()).orElseThrow().getSubscriptionPlan());
        } finally { releaseProvider.countDown(); pool.shutdownNow(); }
    }

    @Test void concurrentDuplicateWebhookCommitsOnlyOneVerifiedSubscriptionEvent() throws Exception {
        var fixture=billingFixture(true);
        when(fixture.provider().getCustomer(personal.getBillingCustomerId())).thenReturn(businessReceipt(true));
        String event="""
                {"event":{"id":"duplicate-business","type":"RENEWAL","environment":"SANDBOX","app_user_id":"%s"}}
                """.formatted(personal.getBillingCustomerId());
        var pool=Executors.newFixedThreadPool(2); var gate=new CountDownLatch(1);
        try {
            List<Future<?>> jobs=new java.util.ArrayList<>();
            for(int i=0;i<2;i++) jobs.add(pool.submit(() -> { gate.await();
                tx.executeWithoutResult(s -> fixture.billing().processRevenueCatWebhook("verified-hook",null,event)); return null;
            }));
            gate.countDown(); for(var job:jobs) job.get(10,TimeUnit.SECONDS);
            verify(fixture.provider(),times(1)).getCustomer(personal.getBillingCustomerId());
            assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM billing_webhook_events WHERE provider_event_id='duplicate-business'",Integer.class));
            assertEquals(SubscriptionPlan.BUSINESS,users.findById(personal.getId()).orElseThrow().getSubscriptionPlan());
        } finally { pool.shutdownNow(); }
    }

    @Test
    void accountDeletionRemovesPersonalVehicleAndInspectionData() {
        Long userId = personal.getId();
        UUID reservationId = UUID.randomUUID();

        tx.executeWithoutResult(status -> {
            assistantAccesses.save(new AiAssistantAccess(personal, NOW));
            assistantDailyUsages.save(new AiAssistantDailyUsage(personal, NOW.toLocalDate(), NOW));
            assistantReservations.save(new AiAssistantQuotaReservation(
                    reservationId, personal, NOW.toLocalDate(), NOW, NOW.plusMinutes(5)));
            // An unrelated user's assistant entitlement must remain untouched.
            assistantAccesses.save(new AiAssistantAccess(owner, NOW));
        });

        Long vehicleId = tx.execute(status -> {
            Vehicle vehicle = vehicles.save(
                    new Vehicle(
                            "35DELETE01",
                            "Brand",
                            "Model",
                            2022,
                            1000,
                            personal
                    )
            );

            DamageInspection inspection = saveInspection(
                    vehicle,
                    personal,
                    NOW,
                    InspectionStatus.COMPLETED
            );
            inspection.setContextImagePath("legacy-context.jpg");

            return vehicle.getId();
        });

        assertNotNull(vehicleId);
        assertTrue(users.findById(userId).isPresent());
        assertTrue(vehicles.findById(vehicleId).isPresent());
        assertTrue(assistantAccesses.findByUserId(userId).isPresent());
        assertTrue(assistantDailyUsages.findByUserIdAndUsageDate(userId, NOW.toLocalDate()).isPresent());
        assertTrue(assistantReservations.existsById(reservationId));
        assertFalse(
                inspections
                        .findAllByVehicleIdOrderByCreatedAtDesc(vehicleId)
                        .isEmpty()
        );

        accountDeletionService.deleteAccount(
                personal.getEmail()
        );

        assertTrue(users.findById(userId).isEmpty());
        assertTrue(vehicles.findById(vehicleId).isEmpty());
        assertTrue(assistantAccesses.findByUserId(userId).isEmpty());
        assertTrue(assistantDailyUsages.findByUserIdAndUsageDate(userId, NOW.toLocalDate()).isEmpty());
        assertFalse(assistantReservations.existsById(reservationId));
        assertTrue(assistantAccesses.findByUserId(owner.getId()).isPresent());
        assertTrue(
                inspections
                        .findAllByVehicleIdOrderByCreatedAtDesc(vehicleId)
                        .isEmpty()
        );

        verify(storage).deleteStoredFile("test.jpg");
        verify(storage).deleteStoredFile("legacy-context.jpg");
    }

    @Test
    void personalAccountKeepsOnlyLatestTwentyInspections() {
        tx.executeWithoutResult(status -> {
            Vehicle personalVehicle =
                    vehicles.save(
                            new Vehicle(
                                    "35RETENTION",
                                    "Brand",
                                    "Model",
                                    2022,
                                    0,
                                    personal
                            )
                    );

            for (int i = 0; i < 20; i++) {
                saveInspection(
                        personalVehicle,
                        personal,
                        NOW,
                        InspectionStatus.COMPLETED
                );
            }
        });

        DamageInspection newestPending =
                tx.execute(status -> {
                    Vehicle personalVehicle =
                            vehicles.findAll().stream()
                                    .filter(vehicle ->
                                            vehicle.getUser() != null
                                                    && vehicle.getUser()
                                                    .getId()
                                                    .equals(personal.getId()))
                                    .findFirst()
                                    .orElseThrow();

                    return saveInspection(
                            personalVehicle,
                            personal,
                            null,
                            InspectionStatus.PENDING
                    );
                });

        Long newestId = newestPending.getId();

        service.analyzeInspection(
                newestId,
                personal.getEmail()
        );

        List<DamageInspection> remaining =
                inspections
                        .findAllByVehicleUserIdAndVehicleBusinessAccountIsNullOrderByCreatedAtDesc(
                                personal.getId()
                        );

        assertEquals(
                20,
                remaining.size()
        );

        assertTrue(
                inspections.findById(newestId).isPresent()
        );

        verify(
                storage,
                times(1)
        ).deleteStoredFile(
                "test.jpg"
        );
    }

    @Test
    void businessAccountKeepsLatestTwentyFinishedInspectionsAndPreservesProcessing() {
        Long processingId =
                tx.execute(status -> {
                    for (int i = 0; i < 20; i++) {
                        saveInspection(
                                i % 2 == 0 ? firstVehicle : secondVehicle,
                                i % 2 == 0 ? owner : member,
                                NOW,
                                InspectionStatus.COMPLETED
                        );
                    }

                    return saveInspection(
                            firstVehicle,
                            owner,
                            NOW,
                            InspectionStatus.PROCESSING
                    ).getId();
                });

        DamageInspection newestPending =
                tx.execute(status ->
                        saveInspection(
                                secondVehicle,
                                member,
                                null,
                                InspectionStatus.PENDING
                        )
                );

        Long newestId = newestPending.getId();

        service.analyzeInspection(
                newestId,
                member.getEmail()
        );

        List<DamageInspection> remaining =
                inspections
                        .findAllByVehicleBusinessAccountIdOrderByCreatedAtDesc(
                                business.getId()
                        );

        assertEquals(
                21,
                remaining.size()
        );

        assertTrue(
                inspections.findById(newestId).isPresent()
        );

        assertTrue(
                inspections.findById(processingId).isPresent()
        );

        long nonProcessingCount =
                remaining.stream()
                        .filter(item ->
                                item.getStatus()
                                        != InspectionStatus.PROCESSING)
                        .count();

        assertEquals(
                20L,
                nonProcessingCount
        );

        verify(
                storage,
                times(1)
        ).deleteStoredFile(
                "test.jpg"
        );
    }

    @Test
    void memberCreatesAndSharesInspectionWhileCreatorRemainsOwnerAfterAnalysisAndReportRetry() {
        var created = service.createInspection(
                firstVehicle.getId(),
                "İzmir",
                38.4,
                27.1,
                owner.getEmail()
        );

        tx.executeWithoutResult(status -> {
            var pair = inspections.findById(created.getId()).orElseThrow();
            pair.setImagePath("test.jpg");
            pair.setContextImagePath("overview.jpg");
        });

        assertEquals(
                owner.getId(),
                service.getMyInspectionById(
                        created.getId(),
                        member.getEmail()
                ).getUserId()
        );

        assertEquals(
                owner.getId(),
                service.analyzeInspection(
                        created.getId(),
                        member.getEmail()
                ).getUserId()
        );

        assertEquals(
                ReportStatus.COMPLETED,
                service.regenerateReport(
                        created.getId(),
                        member.getEmail()
                ).getReportStatus()
        );

        assertEquals(
                1L,
                usages.countByBusinessAccount_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                        business.getId(),
                        START,
                        START.plusDays(1)
                )
        );

        tx.executeWithoutResult(status ->
                vehicles.findById(firstVehicle.getId())
                        .orElseThrow()
                        .setArchived(true)
        );

        assertEquals(
                1,
                service.getMyInspections(member.getEmail()).size()
        );

        assertThrows(
                ResourceNotFoundException.class,
                () -> service.createInspection(
                        firstVehicle.getId(),
                        "İzmir",
                        38.4,
                        27.1,
                        member.getEmail()
                )
        );

        assertThrows(
                ResourceNotFoundException.class,
                () -> service.getMyInspectionById(
                        created.getId(),
                        personal.getEmail()
                )
        );

        tx.executeWithoutResult(status ->
                members.delete(
                        members.findByUserId(owner.getId())
                                .orElseThrow()
                )
        );

        assertThrows(
                ResourceNotFoundException.class,
                () -> service.getMyInspectionById(
                        created.getId(),
                        owner.getEmail()
                )
        );

        assertEquals(
                owner.getId(),
                service.getMyInspectionById(
                        created.getId(),
                        member.getEmail()
                ).getUserId()
        );
    }

    @Test
    void personalHistoryAndCompanyHistoryStaySeparateAfterJoiningCompany() {
        Long personalInspectionId = tx.execute(status -> {
            Vehicle vehicle = vehicles.save(new Vehicle("35PERSONAL", "Brand", "Model", 2022, 0, member));
            return saveInspection(vehicle, member, NOW, InspectionStatus.COMPLETED).getId();
        });
        assertTrue(service.getMyInspections(member.getEmail()).isEmpty());
        assertThrows(ResourceNotFoundException.class,
                () -> service.getMyInspectionById(personalInspectionId, member.getEmail()));
        tx.executeWithoutResult(status -> members.delete(members.findByUserId(member.getId()).orElseThrow()));
        assertEquals(1, service.getMyInspections(member.getEmail()).size());
        assertEquals(member.getId(), service.getMyInspectionById(personalInspectionId, member.getEmail()).getUserId());
    }

    @Test
    void concurrentResetRequestsConsumeTheCodeOnce() throws Exception {
        var resets = app.getBean(PasswordResetService.class);
        var codeRepository = app.getBean(PasswordResetCodeRepository.class);
        tx.executeWithoutResult(status -> codeRepository.save(new PasswordResetCode(
                personal, "code-hash", NOW.plusMinutes(5), NOW)));
        var request = new com.gorkem.vehicle_inspector.dto.request.ResetPasswordRequest();
        request.setEmail(personal.getEmail()); request.setCode("123456");
        request.setNewPassword("new-password"); request.setConfirmNewPassword("new-password");
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Callable<Boolean> action = () -> {
                try { resets.resetPassword(request); return true; }
                catch (IllegalArgumentException alreadyConsumed) { return false; }
            };
            int successes = 0;
            for (var result : pool.invokeAll(List.of(action, action))) if (result.get(10, TimeUnit.SECONDS)) successes++;
            assertEquals(1, successes);
            assertEquals(1, users.findById(personal.getId()).orElseThrow().getAuthVersion());
            assertTrue(codeRepository.findByUserId(personal.getId()).isEmpty());
        } finally { pool.shutdownNow(); }
    }

    @Test
    void concurrentSubscriptionUpdateCannotRestoreOldCredentialGeneration() throws Exception {
        CountDownLatch loaded = new CountDownLatch(1);
        CountDownLatch resetDone = new CountDownLatch(1);
        ExecutorService pool = Executors.newSingleThreadExecutor();
        try {
            Future<?> billing = pool.submit(() -> tx.executeWithoutResult(status -> {
                User staleUser = users.findById(personal.getId()).orElseThrow();
                loaded.countDown();
                try { assertTrue(resetDone.await(10, TimeUnit.SECONDS)); }
                catch (InterruptedException exception) { throw new RuntimeException(exception); }
                staleUser.setSubscriptionPlan(SubscriptionPlan.PRO);
                users.save(staleUser);
            }));
            assertTrue(loaded.await(10, TimeUnit.SECONDS));
            tx.executeWithoutResult(status -> {
                User fresh = users.findByEmailForUpdate(personal.getEmail()).orElseThrow();
                fresh.setPassword("reset-hash"); users.save(fresh);
            });
            resetDone.countDown(); billing.get(10, TimeUnit.SECONDS);
            User result = users.findById(personal.getId()).orElseThrow();
            assertEquals(1, result.getAuthVersion()); assertEquals("reset-hash", result.getPassword());
            assertEquals(SubscriptionPlan.PRO, result.getSubscriptionPlan());
        } finally { resetDone.countDown(); pool.shutdownNow(); }
    }

    @Test
    void employeeQueryExcludesOwnerAndMembershipCanBeRemovedSafely() {
        List<BusinessMember> employees =
                members.findAllByBusinessAccountIdAndRoleOrderByUserFullNameAsc(
                        business.getId(),
                        BusinessRole.MEMBER
                );

        assertEquals(1, employees.size());
        assertEquals(member.getId(), employees.getFirst().getUser().getId());
        assertEquals("Member", employees.getFirst().getUser().getFullName());

        members.delete(employees.getFirst());

        assertFalse(members.existsByUserId(member.getId()));
        assertEquals(2L, vehicles.countByBusinessAccountIdAndArchivedFalse(
                business.getId()
        ));
        assertTrue(members.existsByUserId(owner.getId()));
    }

    @Test
    void twoMembersCannotConsumeTheLastCompanySlotTogether() throws Exception {
        Long[] ids = tx.execute(status -> {
            for (int i = 0; i < 99; i++) {
                usages.save(
                        AnalysisUsage.business(
                                business,
                                NOW
                        )
                );
            }
            return new Long[]{
                    saveInspection(firstVehicle, owner, null, InspectionStatus.PENDING).getId(),
                    saveInspection(secondVehicle, member, null, InspectionStatus.PENDING).getId()
            };
        });
        CountDownLatch firstValidated = new CountDownLatch(1);
        CountDownLatch releaseFirst = new CountDownLatch(1);
        AtomicBoolean first = new AtomicBoolean(true);
        doAnswer(call -> {
            call.callRealMethod();
            if (first.compareAndSet(true, false)) {
                firstValidated.countDown();
                assertTrue(releaseFirst.await(10, TimeUnit.SECONDS));
            }
            return null;
        }).when(subscriptions).validateBusinessMonthlyAnalysisLimit(any(), any());

        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            Future<?> firstRequest = executor.submit(() -> service.analyzeInspection(ids[0], owner.getEmail()));
            assertTrue(firstValidated.await(10, TimeUnit.SECONDS));
            Future<?> secondRequest = executor.submit(() -> service.analyzeInspection(ids[1], member.getEmail()));
            assertThrows(TimeoutException.class, () -> secondRequest.get(300, TimeUnit.MILLISECONDS));
            releaseFirst.countDown();
            firstRequest.get(10, TimeUnit.SECONDS);
            ExecutionException failure = assertThrows(ExecutionException.class,
                    () -> secondRequest.get(10, TimeUnit.SECONDS));
            assertInstanceOf(IllegalStateException.class, failure.getCause());
            assertTrue(failure.getCause().getMessage().contains("100"));
            assertEquals(
                    100L,
                    usages
                            .countByBusinessAccount_IdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
                                    business.getId(),
                                    START,
                                    START.plusDays(1)
                            )
            );
            assertNull(inspections.findById(ids[1]).orElseThrow().getAnalysisStartedAt());
            verify(ai, times(1)).analyze(any(), any(), any());
        } finally {
            releaseFirst.countDown();
            executor.shutdownNow();
            assertTrue(executor.awaitTermination(10, TimeUnit.SECONDS));
        }
    }

    @Test
    void secondMemberCannotStartSameInspectionWhileAnalysisIsRunning() throws Exception {
        Long id = tx.execute(status -> saveInspection(firstVehicle, owner, null, InspectionStatus.PENDING).getId());
        CountDownLatch analyzing = new CountDownLatch(1);
        CountDownLatch finish = new CountDownLatch(1);
        when(ai.analyze(any(), any(), any())).thenAnswer(call -> {
            analyzing.countDown();
            assertTrue(finish.await(10, TimeUnit.SECONDS));
            return GeminiVisionFixtures.success();
        });
        ExecutorService executor = Executors.newSingleThreadExecutor();
        try {
            Future<?> request = executor.submit(() -> service.analyzeInspection(id, owner.getEmail()));
            assertTrue(analyzing.await(10, TimeUnit.SECONDS));
            assertThrows(IllegalStateException.class, () -> service.analyzeInspection(id, member.getEmail()));
            finish.countDown();
            request.get(10, TimeUnit.SECONDS);
            verify(ai, times(1)).analyze(any(), any(), any());
        } finally {
            finish.countDown();
            executor.shutdownNow();
            assertTrue(executor.awaitTermination(10, TimeUnit.SECONDS));
        }
    }

    @Test
    void nearbyServicesUseCompanyAccessAndLoadDataBeforeExternalCalls() {
        Long id = tx.execute(status -> saveInspection(firstVehicle, owner, NOW, InspectionStatus.COMPLETED).getId());
        GeminiNearbyServiceSearchService search = app.getBean(GeminiNearbyServiceSearchService.class);
        GooglePlacesClient places = app.getBean(GooglePlacesClient.class);
        when(search.generateSearchQueries(any())).thenAnswer(call -> {
            assertFalse(TransactionSynchronizationManager.isActualTransactionActive());
            NearbyServiceSearchResult result = new NearbyServiceSearchResult();
            result.searchQueries = List.of("repair service");
            return result;
        });
        when(places.search(anyString(), anyDouble(), anyDouble(), anyDouble())).thenReturn(List.of());

        NearbyServiceService nearby = app.getBean(NearbyServiceService.class);
        assertThrows(ResourceNotFoundException.class, () -> nearby.getNearbyServices(id, personal.getEmail()));
        verifyNoInteractions(search, places);
        assertTrue(nearby.getNearbyServices(id, member.getEmail()).isEmpty());
        verify(search).generateSearchQueries(any());
        verify(places).search("repair service", 38.4, 27.1, 10_000);
    }

    @Test
    void currentAndLegacyAnalysisClassesRemainReadableTogether() {
        Long id=tx.execute(status -> {
            var inspection=saveInspection(firstVehicle,owner,NOW,InspectionStatus.COMPLETED);
            inspection.setDamageSeverity(DamageSeverity.UNKNOWN);
            inspection.setAnalysisSchemaVersion("hitl-v1");
            inspection.setAnalysisModelVersion("persistence-test");
            inspection.setAnalysisPayload("{\"label\":\"Cracked\"}");
            inspection.addRepairRecommendation(new DamageRepairRecommendation(inspection,
                    DamageType.CRACKED,RepairAction.PROFESSIONAL_INSPECTION,null,
                    java.util.Set.of(VehiclePart.BACK_BUMPER)));
            return inspections.saveAndFlush(inspection).getId();
        });
        tx.executeWithoutResult(status -> {
            var stored=inspections.findById(id).orElseThrow();
            assertEquals("hitl-v1",stored.getAnalysisSchemaVersion());
            assertNull(stored.getRepairRecommendations().getFirst().getPartReplacementRequired());
            assertEquals(DamageType.CRACKED,stored.getRepairRecommendations().getFirst().getDamageType());
            assertTrue(stored.getAnalysisPayload().contains("Cracked"));
            assertEquals(DamageType.CRACK,DamageType.valueOf("CRACK"));
        });
    }

    @AfterEach void clearWorkspaceRequest() {
        org.springframework.web.context.request.RequestContextHolder.resetRequestAttributes();
    }

    @Test
    void companyMemberCanReadOwnPersonalHistoryAndImagesWithoutSeeingCompanyRecords() {
        Long personalId = tx.execute(status -> {
            var own = vehicles.save(new Vehicle("PERSONAL-MEMBER", "Brand", "Own", 2024, 1000, member));
            return saveInspection(own, member, NOW, InspectionStatus.COMPLETED).getId();
        });
        Long sharedId = tx.execute(status -> saveInspection(firstVehicle, owner, NOW, InspectionStatus.COMPLETED).getId());
        WorkspaceResolverTest.request("PERSONAL");
        assertEquals(List.of(personalId), service.getMyInspections(member.getEmail()).stream().map(i -> i.getId()).toList());
        assertEquals(Path.of("test.jpg"), service.getInspectionImage(personalId, member.getEmail()));
        assertThrows(ResourceNotFoundException.class, () -> service.getMyInspectionById(sharedId, member.getEmail()));

        WorkspaceResolverTest.request("BUSINESS");
        assertEquals(List.of(sharedId), service.getMyInspections(member.getEmail()).stream().map(i -> i.getId()).toList());
        assertThrows(ResourceNotFoundException.class, () -> service.getInspectionImage(personalId, member.getEmail()));

        tx.executeWithoutResult(status -> members.findByUserId(member.getId()).ifPresent(members::delete));
        assertThrows(com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException.class,
                () -> service.getMyInspectionById(sharedId, member.getEmail()));
        WorkspaceResolverTest.request("PERSONAL");
        assertEquals(personalId, service.getMyInspectionById(personalId, member.getEmail()).getId());
    }

    @Test
    void notificationQueriesAndMarkReadAreWorkspaceScopedAndRevokeCompanyHistory() {
        var notifications = app.getBean(AppNotificationRepository.class);
        var ids = tx.execute(status -> {
            var own = vehicles.save(new Vehicle("PERSONAL-NOTICE", "Brand", "Own", 2024, 1000, member));
            var personalNote = notifications.save(new AppNotification(member, own, null, "own-note",
                    NotificationType.VEHICLE_REMINDER, NotificationSeverity.INFO, "Own", "Own body", null, NOW));
            var sharedNote = notifications.save(new AppNotification(member, firstVehicle, null, "shared-note",
                    NotificationType.VEHICLE_REMINDER, NotificationSeverity.INFO, "Company", "Company body", null, NOW));
            return List.of(personalNote.getId(), sharedNote.getId());
        });
        assertEquals(List.of(ids.getFirst()), tx.execute(status -> notifications.findVisible(member.getId(), null, false,
                org.springframework.data.domain.PageRequest.of(0, 100)).stream().map(AppNotification::getId).toList()));
        long sharedUnread = tx.execute(status -> notifications.countVisibleUnread(member.getId(), business.getId()));
        int marked = tx.execute(status -> notifications.markVisibleRead(member.getId(), null, NOW));
        long remainingShared = tx.execute(status -> notifications.countVisibleUnread(member.getId(), business.getId()));
        assertEquals(1L, sharedUnread);
        assertEquals(1, marked);
        assertEquals(1L, remainingShared);
        assertTrue(Boolean.TRUE.equals(tx.execute(status -> notifications.findVisibleById(ids.getLast(), member.getId(), null).isEmpty())));
        tx.executeWithoutResult(status -> members.findByUserId(member.getId()).ifPresent(members::delete));
        long removedUnread = tx.execute(status -> notifications.countVisibleUnread(member.getId(), business.getId()));
        assertEquals(0L, removedUnread);
    }

    private DamageInspection saveInspection(Vehicle vehicle, User creator, LocalDateTime started, InspectionStatus status) {
        DamageInspection inspection = new DamageInspection(vehicle, creator, status);
        inspection.setAnalysisStartedAt(started);
        inspection.setImagePath("test.jpg");
        inspection.setContextImagePath("overview.jpg");
        inspection.setLocationCity("İzmir");
        inspection.setLocationLatitude(38.4);
        inspection.setLocationLongitude(27.1);
        inspection.setReportStatus(ReportStatus.PENDING);
        inspection.setDamageSeverity(DamageSeverity.NONE);
        return inspections.save(inspection);
    }

    @Configuration
    @EnableTransactionManagement
    @EnableJpaRepositories(basePackageClasses = DamageInspectionRepository.class)
    @Import({
            BusinessContextService.class,
            InspectionAccessService.class,
            DamageInspectionService.class,
            NearbyServiceService.class,
            RegistrationService.class,
            PasswordResetService.class,
            AccountDeletionService.class
    })
    static class PersistenceConfig {
        @Bean com.gorkem.vehicle_inspector.service.billing.BusinessBillingPolicy businessBillingPolicy(DataSource dataSource) {
            return new com.gorkem.vehicle_inspector.service.billing.BusinessBillingPolicy(new JdbcTemplate(dataSource),
                    new com.gorkem.vehicle_inspector.service.billing.BillingSandboxPolicy(""), CLOCK);
        }
        // These existing fixtures deliberately exercise the legacy monthly-quota
        // compatibility path. Production requires CreditWalletService; the real
        // wallet SQL/concurrency is covered by CreditWalletPersistenceTest.
        @Bean CreditWalletService creditWalletService() { return mock(CreditWalletService.class); }
        @Bean AnalysisCreditService analysisCreditService() { return mock(AnalysisCreditService.class); }
        @Bean static org.springframework.beans.factory.config.BeanPostProcessor legacyQuotaFixture() {
            return new org.springframework.beans.factory.config.BeanPostProcessor() {
                @Override public Object postProcessBeforeInitialization(Object bean, String name) {
                    if (bean instanceof SubscriptionService || bean instanceof DamageInspectionService) {
                        org.springframework.test.util.ReflectionTestUtils.setField(bean, "creditWallets", null);
                    }
                    if (bean instanceof DamageInspectionService) {
                        org.springframework.test.util.ReflectionTestUtils.setField(bean, "analysisCreditService", null);
                    }
                    return bean;
                }
            };
        }
        @Bean
        static PropertySourcesPlaceholderConfigurer properties() {
            PropertySourcesPlaceholderConfigurer configurer =
                    new PropertySourcesPlaceholderConfigurer();
            configurer.setProperties(new Properties());
            return configurer;
        }

        @Bean
        DataSource dataSource() {
            String url = System.getProperty("inspection.test.jdbc-url");
            if (!url.matches("jdbc:postgresql://[^/]+/vehicle_inspector_test")) {
                throw new IllegalArgumentException("Use a disposable database named vehicle_inspector_test.");
            }
            return new DriverManagerDataSource(url,
                    System.getProperty("inspection.test.username", "postgres"),
                    System.getProperty("inspection.test.password", ""));
        }

        @Bean
        LocalContainerEntityManagerFactoryBean entityManagerFactory(DataSource dataSource) {
            LocalContainerEntityManagerFactoryBean factory = new LocalContainerEntityManagerFactoryBean();
            factory.setDataSource(dataSource);
            factory.setPackagesToScan(User.class.getPackageName());
            factory.setJpaVendorAdapter(new HibernateJpaVendorAdapter());
            factory.setJpaPropertyMap(Map.of("hibernate.hbm2ddl.auto", "create-drop"));
            return factory;
        }

        @Bean
        PlatformTransactionManager transactionManager(EntityManagerFactory factory) {
            return new JpaTransactionManager(factory);
        }

        @Bean Clock clock() { return CLOCK; }
        @Bean AiAnalysisClient aiAnalysisClient() { return mock(AiAnalysisClient.class); }
        @Bean FileStorageService fileStorageService() { return mock(FileStorageService.class); }
        @Bean GeminiInspectionReportService reportService() { return mock(GeminiInspectionReportService.class); }
        @Bean GeminiNearbyServiceSearchService searchService() { return mock(GeminiNearbyServiceSearchService.class); }
        @Bean GooglePlacesClient googlePlacesClient() { return mock(GooglePlacesClient.class); }
        @Bean PasswordEncoder passwordEncoder() { return mock(PasswordEncoder.class); }
        @Bean VerificationCodeService verificationCodeService() { return mock(VerificationCodeService.class); }
        @Bean EmailService emailService() { return mock(EmailService.class); }

        @Bean
        SubscriptionService subscriptionService(
                AnalysisUsageRepository usages,
                VehicleRepository vehicles
        ) {
            return spy(
                    new SubscriptionService(
                            usages,
                            vehicles,
                            CLOCK
                    )
            );
        }
    }
}
