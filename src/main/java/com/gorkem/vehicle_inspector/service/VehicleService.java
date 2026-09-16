package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.CreateVehicleRequest;
import com.gorkem.vehicle_inspector.dto.request.UpdateVehicleRequest;
import com.gorkem.vehicle_inspector.dto.response.VehicleResponse;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.exception.DuplicateResourceException;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.mapper.VehicleMapper;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import com.gorkem.vehicle_inspector.repository.VehicleMileageRecordRepository;
import com.gorkem.vehicle_inspector.entity.VehicleMileageRecord;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.time.Clock;
import java.time.LocalDateTime;

@Service
public class VehicleService {

    private final VehicleRepository vehicleRepository;
    private final SubscriptionService subscriptionService;
    private final BusinessContextService businessContextService;
    private final VehicleTrackingInitializer trackingInitializer;
    private final VehicleMileageRecordRepository mileageRecords;
    private final Clock clock;

    public VehicleService(
            VehicleRepository vehicleRepository,
            SubscriptionService subscriptionService,
            BusinessContextService businessContextService,
            VehicleTrackingInitializer trackingInitializer,
            VehicleMileageRecordRepository mileageRecords,
            Clock clock
    ) {
        this.vehicleRepository = vehicleRepository;
        this.subscriptionService = subscriptionService;
        this.businessContextService = businessContextService;
        this.trackingInitializer = trackingInitializer;
        this.mileageRecords = mileageRecords;
        this.clock = clock;
    }

    @Transactional
    public VehicleResponse createVehicle(
            CreateVehicleRequest request,
            String authenticatedEmail
    ) {
        User user =
                businessContextService.requireUser(
                        authenticatedEmail
                );

        String normalizedPlate =
                normalizePlate(request.getPlate());

        if (vehicleRepository.existsByPlate(normalizedPlate)) {
            throw new DuplicateResourceException(
                    "Bu plakaya ait araç zaten kayıtlı: "
                            + normalizedPlate
            );
        }

        Vehicle vehicle;

        if (!businessContextService.isBusinessMember(user)) {

            // Kişisel kullanım → kullanıcının kendi plan limiti
            subscriptionService.validateVehicleLimit(user);

            vehicle = VehicleMapper.toEntity(
                    request,
                    user
            );

            boolean hasActiveVehicle =
                    vehicleRepository
                            .countByUserIdAndArchivedFalse(
                                    user.getId()
                            ) > 0;

            vehicle.setPrimaryVehicle(!hasActiveVehicle);

        } else {

            // Business kullanımı → şirketin ortak limiti
            BusinessAccount businessAccount =
                    businessContextService
                            .requireBusinessAccount(user);

            subscriptionService.validateBusinessVehicleLimit(
                    businessAccount
            );

            vehicle = VehicleMapper.toEntity(
                    request,
                    businessAccount
            );

            boolean hasActiveVehicle =
                    vehicleRepository
                            .countByBusinessAccountIdAndArchivedFalse(
                                    businessAccount.getId()
                            ) > 0;

            vehicle.setPrimaryVehicle(!hasActiveVehicle);
        }

        vehicle.initializeCreatedAt(LocalDateTime.now(clock));
        Vehicle savedVehicle = vehicleRepository.save(vehicle);
        trackingInitializer.initialize(savedVehicle, user, request.getTracking());
        return VehicleMapper.toResponse(savedVehicle);
    }

    @Transactional(readOnly = true)
    public List<VehicleResponse> getMyVehicles(
            String authenticatedEmail
    ) {
        User user =
                businessContextService.requireUser(
                        authenticatedEmail
                );

        List<Vehicle> vehicles;

        if (!businessContextService.isBusinessMember(user)) {
            vehicles =
                    vehicleRepository
                            .findAllByUserIdAndArchivedFalseOrderByIdDesc(
                                    user.getId()
                            );
        } else {
            BusinessAccount businessAccount =
                    businessContextService
                            .requireBusinessAccount(user);

            vehicles =
                    vehicleRepository
                            .findAllByBusinessAccountIdAndArchivedFalseOrderByIdDesc(
                                    businessAccount.getId()
                            );
        }

        return vehicles.stream()
                .map(VehicleMapper::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public VehicleResponse getMyVehicleById(
            Long id,
            String authenticatedEmail
    ) {
        User user =
                businessContextService.requireUser(
                        authenticatedEmail
                );

        return VehicleMapper.toResponse(
                findAccessibleVehicle(id, user)
        );
    }

    @Transactional
    public VehicleResponse updateVehicle(
            Long id,
            UpdateVehicleRequest request,
            String authenticatedEmail
    ) {
        User user =
                businessContextService.requireUser(
                        authenticatedEmail
                );

        Vehicle vehicle =
                findAccessibleVehicle(id, user);

        String normalizedPlate = normalizePlate(request.getPlate());

        if (vehicleRepository.existsByPlateAndIdNot(normalizedPlate, id)) {
            throw new DuplicateResourceException(
                    "Bu plaka başka bir araç tarafından kullanılıyor: " + normalizedPlate
            );
        }

        Integer previousMileage = vehicle.getMileage();
        VehicleMapper.updateEntity(vehicle, request);
        if (!previousMileage.equals(request.getMileage())) {
            mileageRecords.save(new VehicleMileageRecord(vehicle, user, previousMileage,
                    request.getMileage(), LocalDateTime.now(clock)));
        }
        return VehicleMapper.toResponse(vehicleRepository.save(vehicle));
    }

    @Transactional
    public VehicleResponse setPrimaryVehicle(
            Long id,
            String authenticatedEmail
    ) {
        User user =
                businessContextService.requireUser(
                        authenticatedEmail
                );

        Vehicle selectedVehicle =
                findAccessibleVehicle(id, user);

        if (!businessContextService.isBusinessMember(user)) {
            vehicleRepository
                    .findByUserIdAndPrimaryVehicleTrueAndArchivedFalse(
                            user.getId()
                    )
                    .filter(current ->
                            !current.getId()
                                    .equals(selectedVehicle.getId())
                    )
                    .ifPresent(current ->
                            current.setPrimaryVehicle(false)
                    );
        } else {
            BusinessAccount businessAccount =
                    businessContextService
                            .requireBusinessAccount(user);

            vehicleRepository
                    .findByBusinessAccountIdAndPrimaryVehicleTrueAndArchivedFalse(
                            businessAccount.getId()
                    )
                    .filter(current ->
                            !current.getId()
                                    .equals(selectedVehicle.getId())
                    )
                    .ifPresent(current ->
                            current.setPrimaryVehicle(false)
                    );
        }

        selectedVehicle.setPrimaryVehicle(true);

        return VehicleMapper.toResponse(
                vehicleRepository.save(selectedVehicle)
        );
    }

    @Transactional
    public void deleteVehicle(
            Long id,
            String authenticatedEmail
    ) {
        User user =
                businessContextService.requireUser(
                        authenticatedEmail
                );

        Vehicle vehicle =
                findAccessibleVehicle(id, user);

        boolean wasPrimary =
                vehicle.isPrimaryVehicle();

        vehicle.setPrimaryVehicle(false);
        vehicle.setArchived(true);

        vehicleRepository.save(vehicle);

        if (!wasPrimary) {
            return;
        }

        List<Vehicle> remainingVehicles;

        if (!businessContextService.isBusinessMember(user)) {
            remainingVehicles =
                    vehicleRepository
                            .findAllByUserIdAndArchivedFalseOrderByIdDesc(
                                    user.getId()
                            );
        } else {
            BusinessAccount businessAccount =
                    businessContextService
                            .requireBusinessAccount(user);

            remainingVehicles =
                    vehicleRepository
                            .findAllByBusinessAccountIdAndArchivedFalseOrderByIdDesc(
                                    businessAccount.getId()
                            );
        }

        remainingVehicles.stream()
                .findFirst()
                .ifPresent(nextVehicle -> {
                    nextVehicle.setPrimaryVehicle(true);
                    vehicleRepository.save(nextVehicle);
                });
    }

    private Vehicle findAccessibleVehicle(
            Long vehicleId,
            User user
    ) {
        if (!businessContextService.isBusinessMember(user)) {
            return vehicleRepository
                    .findByIdAndUserIdAndArchivedFalse(
                            vehicleId,
                            user.getId()
                    )
                    .orElseThrow(() ->
                            vehicleNotFound(vehicleId)
                    );
        }

        BusinessAccount businessAccount =
                businessContextService
                        .requireBusinessAccount(user);

        return vehicleRepository
                .findByIdAndBusinessAccountIdAndArchivedFalse(
                        vehicleId,
                        businessAccount.getId()
                )
                .orElseThrow(() ->
                        vehicleNotFound(vehicleId)
                );
    }

    private ResourceNotFoundException vehicleNotFound(
            Long vehicleId
    ) {
        return new ResourceNotFoundException(
                "Araç bulunamadı. ID: " + vehicleId
        );
    }

    private String normalizePlate(String plate) {
        return plate.trim().toUpperCase();
    }
}
