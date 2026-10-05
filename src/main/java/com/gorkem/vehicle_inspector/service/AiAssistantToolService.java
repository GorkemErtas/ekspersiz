package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class AiAssistantToolService {
    private final BusinessContextService businessContext;
    private final VehicleRepository vehicles;
    private final VehicleAccessService vehicleAccess;
    private final VehicleReminderRepository reminders;
    private final DamageInspectionRepository inspections;

    public AiAssistantToolService(BusinessContextService businessContext, VehicleRepository vehicles,
            VehicleAccessService vehicleAccess, VehicleReminderRepository reminders, DamageInspectionRepository inspections) {
        this.businessContext=businessContext; this.vehicles=vehicles; this.vehicleAccess=vehicleAccess; this.reminders=reminders; this.inspections=inspections;
    }

    @Transactional(readOnly = true)
    public List<AiAssistantVehicleToolResponse> getMyVehicles(String email) {
        User user=businessContext.requireUser(email);
        List<Vehicle> result;
        if (businessContext.findMembership(user).isPresent()) {
            var business=businessContext.requireBusinessAccount(user);
            result=vehicles.findAllByBusinessAccountIdAndArchivedFalseOrderByIdDesc(business.getId());
        } else result=vehicles.findAllByUserIdAndArchivedFalseOrderByIdDesc(user.getId());
        return result.stream().map(this::vehicleDto).toList();
    }

    @Transactional(readOnly = true)
    public AiAssistantVehicleToolResponse getVehicle(Long vehicleId, String email) {
        User user=businessContext.requireUser(email);
        return vehicleDto(vehicleAccess.requireActiveVehicle(vehicleId, user));
    }

    @Transactional(readOnly = true)
    public List<AiAssistantReminderToolResponse> getUpcomingReminders(Long vehicleId, String email) {
        User user=businessContext.requireUser(email); vehicleAccess.requireActiveVehicle(vehicleId, user);
        return reminders.findAllByVehicleIdAndCompletedAtIsNullOrderByDueDateAscIdAsc(vehicleId).stream().limit(10)
                .map(r -> new AiAssistantReminderToolResponse(r.getId(), r.getReminderType().name(), r.getTitle(), r.getDueDate(), r.getDueMileage())).toList();
    }

    @Transactional(readOnly = true)
    public List<AiAssistantDamageToolResponse> getDamageHistory(Long vehicleId, String email) {
        User user=businessContext.requireUser(email); vehicleAccess.requireActiveVehicle(vehicleId, user);
        return inspections.findAllByVehicleIdOrderByCreatedAtDesc(vehicleId).stream()
                .filter(i -> i.getStatus() == InspectionStatus.COMPLETED).limit(10)
                .map(i -> new AiAssistantDamageToolResponse(i.getId(), i.getDamageSeverity()==null?null:i.getDamageSeverity().name(),
                        i.getConfidenceScore(), i.getAnalysisMessage(), i.getCompletedAt())).toList();
    }

    private AiAssistantVehicleToolResponse vehicleDto(Vehicle v) {
        return new AiAssistantVehicleToolResponse(v.getId(), v.getPlate(), v.getBrand(), v.getModel(), v.getModelYear(), v.getMileage(), v.isPrimaryVehicle());
    }
}
