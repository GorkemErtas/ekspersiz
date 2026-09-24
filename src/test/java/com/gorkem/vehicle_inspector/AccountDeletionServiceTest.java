package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.AccountDeletionService;
import com.gorkem.vehicle_inspector.service.FileStorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AccountDeletionServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private VehicleRepository vehicleRepository;

    @Mock
    private DamageInspectionRepository damageInspectionRepository;

    @Mock
    private MaintenanceRecordRepository maintenanceRecordRepository;

    @Mock
    private VehicleMileageRecordRepository mileageRecordRepository;

    @Mock
    private VehicleReminderRepository reminderRepository;

    @Mock
    private AppNotificationRepository notificationRepository;

    @Mock
    private DeviceTokenRepository deviceTokenRepository;

    @Mock
    private AnalysisUsageRepository analysisUsageRepository;

    @Mock
    private BillingSubscriptionRepository billingSubscriptionRepository;

    @Mock
    private BusinessInvitationRepository businessInvitationRepository;

    @Mock
    private BusinessMemberRepository businessMemberRepository;

    @Mock
    private PasswordResetCodeRepository passwordResetCodeRepository;

    @Mock
    private FileStorageService fileStorageService;

    private AccountDeletionService service;

    @BeforeEach
    void setUp() {
        service = new AccountDeletionService(
                userRepository,
                vehicleRepository,
                damageInspectionRepository,
                maintenanceRecordRepository,
                mileageRecordRepository,
                reminderRepository,
                notificationRepository,
                deviceTokenRepository,
                analysisUsageRepository,
                billingSubscriptionRepository,
                businessInvitationRepository,
                businessMemberRepository,
                passwordResetCodeRepository,
                fileStorageService
        );
    }

    @Test
    void shouldRejectDeletionWhenUserDoesNotExist() {

        assertThrows(
                ResourceNotFoundException.class,
                () -> service.deleteAccount(
                        " MISSING@EXAMPLE.COM "
                )
        );

        verify(userRepository, never()).delete(any());
    }

    @Test
    void shouldRejectDeletionForBusinessOwner() {
        User user = mockUser(1L);

        BusinessMember membership =
                mock(BusinessMember.class);

        when(userRepository.findByEmail("owner@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.findByUserId(1L))
                .thenReturn(Optional.of(membership));

        when(membership.getRole())
                .thenReturn(BusinessRole.OWNER);

        IllegalStateException exception =
                assertThrows(
                        IllegalStateException.class,
                        () -> service.deleteAccount(
                                "owner@example.com"
                        )
                );

        assertTrue(
                exception.getMessage()
                        .contains("Şirket sahibi")
        );

        verify(userRepository, never()).delete(any());
        verify(vehicleRepository, never())
                .deleteAll(any());
    }

    @Test
    void shouldRejectDeletionForBusinessMember() {
        User user = mockUser(2L);

        BusinessMember membership =
                mock(BusinessMember.class);

        when(userRepository.findByEmail("member@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.findByUserId(2L))
                .thenReturn(Optional.of(membership));

        when(membership.getRole())
                .thenReturn(BusinessRole.MEMBER);

        IllegalStateException exception =
                assertThrows(
                        IllegalStateException.class,
                        () -> service.deleteAccount(
                                "member@example.com"
                        )
                );

        assertTrue(
                exception.getMessage()
                        .contains("Şirkete bağlı")
        );

        verify(userRepository, never()).delete(any());
        verify(vehicleRepository, never())
                .deleteAll(any());
    }

    @Test
    void shouldDeletePersonalUserWithoutVehicles() {
        User user = mockUser(3L);

        when(userRepository.findByEmail("personal@example.com"))
                .thenReturn(Optional.of(user));

        when(businessMemberRepository.findByUserId(3L))
                .thenReturn(Optional.empty());

        when(vehicleRepository.findAllByUserId(3L))
                .thenReturn(List.of());

        service.deleteAccount(" PERSONAL@EXAMPLE.COM ");

        verify(notificationRepository)
                .deleteAllByUserId(3L);

        verify(deviceTokenRepository)
                .deleteAllByUserId(3L);

        verify(analysisUsageRepository)
                .deleteAllByUserId(3L);

        verify(billingSubscriptionRepository)
                .deleteByUserId(3L);

        verify(businessInvitationRepository)
                .deleteByUserId(3L);

        verify(passwordResetCodeRepository)
                .deleteByUserId(3L);

        verify(vehicleRepository)
                .deleteAll(List.of());

        verify(userRepository)
                .delete(user);

        verifyNoInteractions(fileStorageService);
    }

    private User mockUser(Long id) {
        User user = mock(User.class);

        when(user.getId())
                .thenReturn(id);

        return user;
    }
}