package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import com.gorkem.vehicle_inspector.service.SubscriptionService;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SubscriptionServiceTest {

    @Mock
    private DamageInspectionRepository inspectionRepository;

    @Mock
    private VehicleRepository vehicleRepository;

    @Mock
    private User user;

    private SubscriptionService subscriptionService;

    @BeforeEach
    void setUp() {
        subscriptionService =
                new SubscriptionService(
                        inspectionRepository,
                        vehicleRepository,
                        Clock.systemDefaultZone()
                );
    }

    @Test
    void freeUserShouldBeBlockedAfterThreeInspections() {
        when(user.getId())
                .thenReturn(1L);

        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.FREE);

        when(
                inspectionRepository
                        .countPersonalAnalysesBetween(
                                eq(1L),
                                any(LocalDateTime.class),
                                any(LocalDateTime.class)
                        )
        ).thenReturn(3L);

        assertThrows(
                IllegalStateException.class,
                () -> subscriptionService
                        .validateInspectionLimit(user)
        );
    }

    @Test
    void plusUserShouldBeAllowedBeforeFifteenInspections() {
        when(user.getId())
                .thenReturn(1L);

        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.PLUS);

        when(user.getSubscriptionExpiresAt())
                .thenReturn(
                        LocalDateTime.now()
                                .plusDays(30)
                );

        when(
                inspectionRepository
                        .countPersonalAnalysesBetween(
                                eq(1L),
                                any(LocalDateTime.class),
                                any(LocalDateTime.class)
                        )
        ).thenReturn(14L);

        assertDoesNotThrow(
                () -> subscriptionService
                        .validateInspectionLimit(user)
        );
    }

    @Test
    void plusUserShouldBeBlockedAtFifteenInspections() {
        when(user.getId())
                .thenReturn(1L);

        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.PLUS);

        when(user.getSubscriptionExpiresAt())
                .thenReturn(
                        LocalDateTime.now()
                                .plusDays(30)
                );

        when(
                inspectionRepository
                        .countPersonalAnalysesBetween(
                                eq(1L),
                                any(LocalDateTime.class),
                                any(LocalDateTime.class)
                        )
        ).thenReturn(15L);

        assertThrows(
                IllegalStateException.class,
                () -> subscriptionService
                        .validateInspectionLimit(user)
        );
    }

    @Test
    void proUserShouldHaveUnlimitedInspections() {
        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.PRO);

        when(user.getSubscriptionExpiresAt())
                .thenReturn(
                        LocalDateTime.now()
                                .plusDays(30)
                );

        assertDoesNotThrow(
                () -> subscriptionService
                        .validateInspectionLimit(user)
        );

        verifyNoInteractions(
                inspectionRepository
        );
    }

    @Test
    void freeUserShouldBeBlockedAfterOneVehicle() {
        when(user.getId())
                .thenReturn(1L);

        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.FREE);

        when(
                vehicleRepository.countByUserIdAndArchivedFalse(1L)
        ).thenReturn(1L);

        assertThrows(
                IllegalStateException.class,
                () -> subscriptionService
                        .validateVehicleLimit(user)
        );
    }

    @Test
    void plusUserShouldBeBlockedAfterFiveVehicles() {
        when(user.getId())
                .thenReturn(1L);

        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.PLUS);

        when(user.getSubscriptionExpiresAt())
                .thenReturn(
                        LocalDateTime.now()
                                .plusDays(30)
                );

        when(
                vehicleRepository.countByUserIdAndArchivedFalse(1L)
        ).thenReturn(5L);

        assertThrows(
                IllegalStateException.class,
                () -> subscriptionService
                        .validateVehicleLimit(user)
        );
    }

    @Test
    void expiredPlusShouldBehaveAsFree() {
        when(user.getId())
                .thenReturn(1L);

        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.PLUS);

        when(user.getSubscriptionExpiresAt())
                .thenReturn(
                        LocalDateTime.now()
                                .minusDays(1)
                );

        when(
                vehicleRepository.countByUserIdAndArchivedFalse(1L)
        ).thenReturn(1L);

        assertThrows(
                IllegalStateException.class,
                () -> subscriptionService
                        .validateVehicleLimit(user)
        );
    }

    @Test
    void businessShouldBeAllowedBeforeFiftyVehicles() {
        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        org.springframework.test.util.ReflectionTestUtils.setField(
                businessAccount,
                "id",
                10L
        );

        when(
                vehicleRepository
                        .countByBusinessAccountIdAndArchivedFalse(10L)
        ).thenReturn(49L);

        assertDoesNotThrow(
                () -> subscriptionService
                        .validateBusinessVehicleLimit(
                                businessAccount
                        )
        );
    }

    @Test
    void businessShouldBeBlockedAtFiftyVehicles() {
        BusinessAccount businessAccount =
                new BusinessAccount("ABC Ekspertiz");

        org.springframework.test.util.ReflectionTestUtils.setField(
                businessAccount,
                "id",
                10L
        );

        when(
                vehicleRepository
                        .countByBusinessAccountIdAndArchivedFalse(10L)
        ).thenReturn(50L);

        assertThrows(
                IllegalStateException.class,
                () -> subscriptionService
                        .validateBusinessVehicleLimit(
                                businessAccount
                        )
        );
    }

    @ParameterizedTest
    @ValueSource(longs = {0, 99})
    void businessShouldAllowBeforeDailyLimit(long used) {
        BusinessAccount business = mock(BusinessAccount.class);
        when(business.getId()).thenReturn(10L);
        Clock clock = Clock.fixed(Instant.parse("2026-09-15T21:00:00Z"), ZoneId.of("Europe/Istanbul"));
        SubscriptionService service = new SubscriptionService(inspectionRepository, vehicleRepository, clock);
        LocalDateTime start = LocalDateTime.of(2026, 9, 16, 0, 0);
        when(inspectionRepository.countBusinessAnalysesBetween(10L, start, start.plusDays(1)))
                .thenReturn(used);

        assertDoesNotThrow(() -> service.validateBusinessInspectionLimit(business));

        verify(inspectionRepository).countBusinessAnalysesBetween(10L, start, start.plusDays(1));
        verifyNoMoreInteractions(inspectionRepository);
        verifyNoInteractions(user, vehicleRepository);
    }

    @ParameterizedTest
    @ValueSource(longs = {100, 101})
    void businessShouldRejectAtOrAboveDailyLimit(long used) {
        BusinessAccount business = mock(BusinessAccount.class);
        when(business.getId()).thenReturn(10L);
        when(inspectionRepository.countBusinessAnalysesBetween(eq(10L), any(), any()))
                .thenReturn(used);

        assertThrows(IllegalStateException.class,
                () -> subscriptionService.validateBusinessInspectionLimit(business));
        verifyNoInteractions(user, vehicleRepository);
    }
}
