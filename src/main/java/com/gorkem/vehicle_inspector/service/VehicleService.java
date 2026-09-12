package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.CreateVehicleRequest;
import com.gorkem.vehicle_inspector.dto.request.UpdateVehicleRequest;
import com.gorkem.vehicle_inspector.dto.response.VehicleResponse;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.entity.Vehicle;
import com.gorkem.vehicle_inspector.exception.DuplicateResourceException;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.mapper.VehicleMapper;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import com.gorkem.vehicle_inspector.repository.VehicleRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class VehicleService {

    private final VehicleRepository vehicleRepository;
    private final UserRepository userRepository;
    private final SubscriptionService subscriptionService;

    public VehicleService(
            VehicleRepository vehicleRepository,
            UserRepository userRepository,
            SubscriptionService subscriptionService
    ) {
        this.vehicleRepository = vehicleRepository;
        this.userRepository = userRepository;
        this.subscriptionService = subscriptionService;
    }

    @Transactional
    public VehicleResponse createVehicle(
            CreateVehicleRequest request,
            String authenticatedEmail
    ) {
        User user = findUserByEmail(authenticatedEmail);
        subscriptionService.validateVehicleLimit(user);

        String normalizedPlate = normalizePlate(request.getPlate());

        if (vehicleRepository.existsByPlate(normalizedPlate)) {
            throw new DuplicateResourceException(
                    "Bu plakaya ait araç zaten kayıtlı: " + normalizedPlate
            );
        }

        Vehicle vehicle = VehicleMapper.toEntity(request, user);

        boolean hasActiveVehicle =
                vehicleRepository.countByUserIdAndArchivedFalse(user.getId()) > 0;

        vehicle.setPrimaryVehicle(!hasActiveVehicle);

        return VehicleMapper.toResponse(vehicleRepository.save(vehicle));
    }

    @Transactional(readOnly = true)
    public List<VehicleResponse> getMyVehicles(String authenticatedEmail) {
        User user = findUserByEmail(authenticatedEmail);

        return vehicleRepository
                .findAllByUserIdAndArchivedFalseOrderByIdDesc(user.getId())
                .stream()
                .map(VehicleMapper::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public VehicleResponse getMyVehicleById(Long id, String authenticatedEmail) {
        User user = findUserByEmail(authenticatedEmail);
        return VehicleMapper.toResponse(findVehicleByIdAndUserId(id, user.getId()));
    }

    @Transactional
    public VehicleResponse updateVehicle(
            Long id,
            UpdateVehicleRequest request,
            String authenticatedEmail
    ) {
        User user = findUserByEmail(authenticatedEmail);
        Vehicle vehicle = findVehicleByIdAndUserId(id, user.getId());

        String normalizedPlate = normalizePlate(request.getPlate());

        if (vehicleRepository.existsByPlateAndIdNot(normalizedPlate, id)) {
            throw new DuplicateResourceException(
                    "Bu plaka başka bir araç tarafından kullanılıyor: " + normalizedPlate
            );
        }

        VehicleMapper.updateEntity(vehicle, request);
        return VehicleMapper.toResponse(vehicleRepository.save(vehicle));
    }

    @Transactional
    public VehicleResponse setPrimaryVehicle(Long id, String authenticatedEmail) {
        User user = findUserByEmail(authenticatedEmail);
        Vehicle selectedVehicle = findVehicleByIdAndUserId(id, user.getId());

        vehicleRepository
                .findByUserIdAndPrimaryVehicleTrueAndArchivedFalse(user.getId())
                .filter(current -> !current.getId().equals(selectedVehicle.getId()))
                .ifPresent(current -> current.setPrimaryVehicle(false));

        selectedVehicle.setPrimaryVehicle(true);

        return VehicleMapper.toResponse(vehicleRepository.save(selectedVehicle));
    }

    @Transactional
    public void deleteVehicle(Long id, String authenticatedEmail) {
        User user = findUserByEmail(authenticatedEmail);
        Vehicle vehicle = findVehicleByIdAndUserId(id, user.getId());

        boolean wasPrimary = vehicle.isPrimaryVehicle();

        vehicle.setPrimaryVehicle(false);
        vehicle.setArchived(true);
        vehicleRepository.save(vehicle);

        if (wasPrimary) {
            vehicleRepository
                    .findAllByUserIdAndArchivedFalseOrderByIdDesc(user.getId())
                    .stream()
                    .findFirst()
                    .ifPresent(nextVehicle -> {
                        nextVehicle.setPrimaryVehicle(true);
                        vehicleRepository.save(nextVehicle);
                    });
        }
    }

    private User findUserByEmail(String email) {
        String normalizedEmail = email.trim().toLowerCase();

        return userRepository
                .findByEmail(normalizedEmail)
                .orElseThrow(() ->
                        new ResourceNotFoundException("Kullanıcı bulunamadı.")
                );
    }

    private Vehicle findVehicleByIdAndUserId(Long vehicleId, Long userId) {
        return vehicleRepository
                .findByIdAndUserIdAndArchivedFalse(vehicleId, userId)
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Araç bulunamadı. ID: " + vehicleId
                        )
                );
    }

    private String normalizePlate(String plate) {
        return plate.trim().toUpperCase();
    }
}
