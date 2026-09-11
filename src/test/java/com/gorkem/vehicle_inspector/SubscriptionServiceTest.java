package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.Role;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.DamageInspectionRepository;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import com.gorkem.vehicle_inspector.service.SubscriptionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;

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
                        vehicleRepository
                );

        when(user.getRole())
                .thenReturn(Role.USER);
    }

    @Test
    void freeUserShouldBeBlockedAfterThreeInspections() {
        when(user.getId())
                .thenReturn(1L);

        when(user.getSubscriptionPlan())
                .thenReturn(SubscriptionPlan.FREE);

        when(
                inspectionRepository
                        .countByUserIdAndAnalysisStartedAtGreaterThanEqualAndAnalysisStartedAtLessThan(
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
                        .countByUserIdAndAnalysisStartedAtGreaterThanEqualAndAnalysisStartedAtLessThan(
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
                        .countByUserIdAndAnalysisStartedAtGreaterThanEqualAndAnalysisStartedAtLessThan(
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
                vehicleRepository.countByUserId(1L)
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
                vehicleRepository.countByUserId(1L)
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
                vehicleRepository.countByUserId(1L)
        ).thenReturn(1L);

        assertThrows(
                IllegalStateException.class,
                () -> subscriptionService
                        .validateVehicleLimit(user)
        );
    }
}