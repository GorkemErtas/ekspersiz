package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.*;
import java.util.List;

/** Visual observations, never fabricated detector boxes or calibrated confidence. */
public record VisualFindingResponse(DamageType damageType, VehiclePart affectedPart,
        DamageSeverity severity, String description, RepairAction recommendedAction,
        String repairNotes, String replacementAssessment, List<String> evidenceImages) {}
