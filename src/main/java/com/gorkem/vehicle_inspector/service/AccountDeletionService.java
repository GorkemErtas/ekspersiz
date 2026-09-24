package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.DamageInspection;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

@Service
public class AccountDeletionService {

    private final UserRepository userRepository;
    private final VehicleRepository vehicleRepository;
    private final DamageInspectionRepository damageInspectionRepository;
    private final MaintenanceRecordRepository maintenanceRecordRepository;
    private final VehicleMileageRecordRepository mileageRecordRepository;
    private final VehicleReminderRepository reminderRepository;
    private final AppNotificationRepository notificationRepository;
    private final DeviceTokenRepository deviceTokenRepository;
    private final AnalysisUsageRepository analysisUsageRepository;
    private final BillingSubscriptionRepository billingSubscriptionRepository;
    private final BusinessInvitationRepository businessInvitationRepository;
    private final BusinessMemberRepository businessMemberRepository;
    private final PasswordResetCodeRepository passwordResetCodeRepository;
    private final FileStorageService fileStorageService;

    public AccountDeletionService(
            UserRepository userRepository,
            VehicleRepository vehicleRepository,
            DamageInspectionRepository damageInspectionRepository,
            MaintenanceRecordRepository maintenanceRecordRepository,
            VehicleMileageRecordRepository mileageRecordRepository,
            VehicleReminderRepository reminderRepository,
            AppNotificationRepository notificationRepository,
            DeviceTokenRepository deviceTokenRepository,
            AnalysisUsageRepository analysisUsageRepository,
            BillingSubscriptionRepository billingSubscriptionRepository,
            BusinessInvitationRepository businessInvitationRepository,
            BusinessMemberRepository businessMemberRepository,
            PasswordResetCodeRepository passwordResetCodeRepository,
            FileStorageService fileStorageService
    ) {
        this.userRepository = userRepository;
        this.vehicleRepository = vehicleRepository;
        this.damageInspectionRepository = damageInspectionRepository;
        this.maintenanceRecordRepository = maintenanceRecordRepository;
        this.mileageRecordRepository = mileageRecordRepository;
        this.reminderRepository = reminderRepository;
        this.notificationRepository = notificationRepository;
        this.deviceTokenRepository = deviceTokenRepository;
        this.analysisUsageRepository = analysisUsageRepository;
        this.billingSubscriptionRepository = billingSubscriptionRepository;
        this.businessInvitationRepository = businessInvitationRepository;
        this.businessMemberRepository = businessMemberRepository;
        this.passwordResetCodeRepository = passwordResetCodeRepository;
        this.fileStorageService = fileStorageService;
    }

    @Transactional
    public void deleteAccount(String authenticatedEmail) {
        User user = userRepository
                .findByEmail(normalizeEmail(authenticatedEmail))
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Kullanıcı bulunamadı."
                        )
                );

        Long userId = user.getId();

        BusinessMember membership = businessMemberRepository
                .findByUserId(userId)
                .orElse(null);

        if (membership != null) {
            throw new IllegalStateException(
                    membership.getRole() == BusinessRole.OWNER
                            ? "Şirket sahibi hesabı doğrudan silinemez. "
                              + "Önce şirket hesabını kapatmanız veya sahipliği devretmeniz gerekir."
                            : "Şirkete bağlı hesap doğrudan silinemez. "
                              + "Hesabınızı silmeden önce şirket üyeliğinizin kaldırılması gerekir."
            );
        }

        /*
         * Yalnızca kullanıcıya ait kişisel araçları sil.
         * Business araçları BusinessAccount'a bağlıdır ve korunur.
         */
        List<Vehicle> personalVehicles =
                vehicleRepository.findAllByUserId(userId);

        Set<String> imagePaths = new LinkedHashSet<>();

        /*
         * Bildirimler vehicle FK'si de taşıdığı için araçlardan önce silinir.
         */
        notificationRepository.deleteAllByUserId(userId);

        for (Vehicle vehicle : personalVehicles) {
            Long vehicleId = vehicle.getId();

            List<DamageInspection> inspections =
                    damageInspectionRepository
                            .findAllByVehicleIdOrderByCreatedAtDesc(
                                    vehicleId
                            );

            inspections.stream()
                    .map(DamageInspection::getImagePath)
                    .filter(path ->
                            path != null && !path.isBlank()
                    )
                    .forEach(imagePaths::add);

            reminderRepository.deleteAllByVehicleId(vehicleId);
            maintenanceRecordRepository.deleteAllByVehicleId(vehicleId);
            mileageRecordRepository.deleteAllByVehicleId(vehicleId);

            /*
             * Entity cascade'i inspection altındaki detection,
             * recommendation ve report kayıtlarını temizler.
             */
            damageInspectionRepository.deleteAllByVehicleId(vehicleId);
        }

        vehicleRepository.deleteAll(personalVehicles);

        /*
         * Kullanıcıya doğrudan bağlı kişisel kayıtlar.
         */
        deviceTokenRepository.deleteAllByUserId(userId);
        analysisUsageRepository.deleteAllByUserId(userId);
        billingSubscriptionRepository.deleteByUserId(userId);
        businessInvitationRepository.deleteByUserId(userId);
        passwordResetCodeRepository.deleteByUserId(userId);

        userRepository.delete(user);

        registerImageDeletionAfterCommit(imagePaths);
    }

    private void registerImageDeletionAfterCommit(
            Set<String> imagePaths
    ) {
        if (imagePaths.isEmpty()) {
            return;
        }

        if (!TransactionSynchronizationManager
                .isSynchronizationActive()) {
            throw new IllegalStateException(
                    "Hesap silme işlemi aktif bir transaction gerektiriyor."
            );
        }

        TransactionSynchronizationManager
                .registerSynchronization(
                        new TransactionSynchronization() {
                            @Override
                            public void afterCompletion(int status) {
                                if (status
                                        != TransactionSynchronization.STATUS_COMMITTED) {
                                    return;
                                }

                                for (String imagePath : imagePaths) {
                                    deleteImageSafely(imagePath);
                                }
                            }
                        }
                );
    }

    private void deleteImageSafely(String imagePath) {
        try {
            fileStorageService.deleteStoredFile(imagePath);
        } catch (RuntimeException ignored) {
            /*
             * DB silme işlemi başarıyla tamamlandıktan sonra
             * dosya temizleme hatası hesabı geri getirmemeli.
             */
        }
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }
}