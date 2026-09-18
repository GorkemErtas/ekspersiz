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
import org.springframework.mail.javamail.JavaMailSender;
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
    private PasswordEncoder passwordEncoder;
    private VerificationCodeService verificationCodes;
    private JavaMailSender mailSender;
    private AiAnalysisClient ai;
    private GeminiInspectionReportService reports;
    private FileStorageService storage;
    private User owner;
    private User member;
    private User personal;
    private BusinessAccount business;
    private Vehicle firstVehicle;
    private Vehicle secondVehicle;

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
        passwordEncoder = app.getBean(PasswordEncoder.class);
        verificationCodes = app.getBean(VerificationCodeService.class);
        mailSender = app.getBean(JavaMailSender.class);
        ai = app.getBean(AiAnalysisClient.class);
        reports = app.getBean(GeminiInspectionReportService.class);
        storage = app.getBean(FileStorageService.class);
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
                verificationCodes, mailSender,
                app.getBean(GeminiNearbyServiceSearchService.class), app.getBean(GooglePlacesClient.class));
        lenient().when(ai.validateImage(any())).thenReturn(
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
        when(ai.analyze(any())).thenAnswer(call -> {
            assertFalse(TransactionSynchronizationManager.isActualTransactionActive());
            AiAnalysisResponse response = new AiAnalysisResponse();
            response.setDamageSeverity(DamageSeverity.NONE);
            return response;
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

    @Test
    void companyCountUsesVehicleScopeDateBoundariesAndIncludesArchivedVehicles() {
        tx.executeWithoutResult(status -> {
            secondVehicle.setArchived(true);
            vehicles.save(secondVehicle);
            saveInspection(firstVehicle, owner, START, InspectionStatus.COMPLETED);
            saveInspection(secondVehicle, member, NOW, InspectionStatus.FAILED);
            saveInspection(firstVehicle, member, START.plusDays(1).minusNanos(1000), InspectionStatus.PROCESSING);
            saveInspection(firstVehicle, owner, START.minusNanos(1000), InspectionStatus.COMPLETED);
            saveInspection(firstVehicle, owner, START.plusDays(1), InspectionStatus.COMPLETED);
            saveInspection(firstVehicle, member, null, InspectionStatus.PENDING);

            BusinessAccount other = businesses.save(new BusinessAccount("Other Company"));
            Vehicle otherVehicle = vehicles.save(new Vehicle("35OTHER", "Brand", "Model", 2022, 0, other));
            saveInspection(otherVehicle, owner, NOW, InspectionStatus.COMPLETED);
            Vehicle personalVehicle = vehicles.save(new Vehicle("35OWN", "Brand", "Model", 2022, 0, owner));
            saveInspection(personalVehicle, owner, NOW, InspectionStatus.COMPLETED);
        });

        assertEquals(3L, inspections.countBusinessAnalysesBetween(business.getId(), START, START.plusDays(1)));
        assertEquals(1L, inspections.countPersonalAnalysesBetween(owner.getId(), START, START.plusDays(1)));
    }

    @Test
    void memberCreatesAndSharesInspectionWhileCreatorRemainsOwnerAfterAnalysisAndReportRetry() {
        var created = service.createInspection(firstVehicle.getId(), "İzmir", 38.4, 27.1, owner.getEmail());
        tx.executeWithoutResult(status -> inspections.findById(created.getId()).orElseThrow().setImagePath("test.jpg"));

        assertEquals(owner.getId(), service.getMyInspectionById(created.getId(), member.getEmail()).getUserId());
        assertEquals(owner.getId(), service.analyzeInspection(created.getId(), member.getEmail()).getUserId());
        assertEquals(ReportStatus.COMPLETED,
                service.regenerateReport(created.getId(), member.getEmail()).getReportStatus());
        assertEquals(1L, inspections.countBusinessAnalysesBetween(business.getId(), START, START.plusDays(1)));

        tx.executeWithoutResult(status -> vehicles.findById(firstVehicle.getId()).orElseThrow().setArchived(true));
        assertEquals(1, service.getMyInspections(member.getEmail()).size());
        assertThrows(ResourceNotFoundException.class,
                () -> service.createInspection(firstVehicle.getId(), "İzmir", 38.4, 27.1, member.getEmail()));
        assertThrows(ResourceNotFoundException.class,
                () -> service.getMyInspectionById(created.getId(), personal.getEmail()));
        tx.executeWithoutResult(status -> members.delete(members.findByUserId(owner.getId()).orElseThrow()));
        assertThrows(ResourceNotFoundException.class,
                () -> service.getMyInspectionById(created.getId(), owner.getEmail()));
        assertEquals(owner.getId(), service.getMyInspectionById(created.getId(), member.getEmail()).getUserId());
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
                saveInspection(i % 2 == 0 ? firstVehicle : secondVehicle,
                        i % 2 == 0 ? owner : member, NOW, InspectionStatus.COMPLETED);
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
            assertEquals(100L, inspections.countBusinessAnalysesBetween(business.getId(), START, START.plusDays(1)));
            assertNull(inspections.findById(ids[1]).orElseThrow().getAnalysisStartedAt());
            verify(ai, times(1)).analyze(any());
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
        when(ai.analyze(any())).thenAnswer(call -> {
            analyzing.countDown();
            assertTrue(finish.await(10, TimeUnit.SECONDS));
            AiAnalysisResponse response = new AiAnalysisResponse();
            response.setDamageSeverity(DamageSeverity.NONE);
            return response;
        });
        ExecutorService executor = Executors.newSingleThreadExecutor();
        try {
            Future<?> request = executor.submit(() -> service.analyzeInspection(id, owner.getEmail()));
            assertTrue(analyzing.await(10, TimeUnit.SECONDS));
            assertThrows(IllegalStateException.class, () -> service.analyzeInspection(id, member.getEmail()));
            finish.countDown();
            request.get(10, TimeUnit.SECONDS);
            verify(ai, times(1)).analyze(any());
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

    private DamageInspection saveInspection(Vehicle vehicle, User creator, LocalDateTime started, InspectionStatus status) {
        DamageInspection inspection = new DamageInspection(vehicle, creator, status);
        inspection.setAnalysisStartedAt(started);
        inspection.setImagePath("test.jpg");
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
    @Import({BusinessContextService.class, InspectionAccessService.class,
            DamageInspectionService.class, NearbyServiceService.class,
            RegistrationService.class})
    static class PersistenceConfig {
        @Bean
        static PropertySourcesPlaceholderConfigurer properties() {
            PropertySourcesPlaceholderConfigurer configurer =
                    new PropertySourcesPlaceholderConfigurer();
            Properties properties = new Properties();
            properties.setProperty("spring.mail.username", "test@example.com");
            configurer.setProperties(properties);
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
        @Bean JavaMailSender mailSender() { return mock(JavaMailSender.class); }

        @Bean
        SubscriptionService subscriptionService(DamageInspectionRepository inspections, VehicleRepository vehicles) {
            return spy(new SubscriptionService(inspections, vehicles, CLOCK));
        }
    }
}
