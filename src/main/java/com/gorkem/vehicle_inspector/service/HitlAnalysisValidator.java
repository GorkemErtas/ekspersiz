package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.AiServiceException;
import java.util.*;

/** Reject fabricated classes, confidence, severity and unsupported repair decisions. */
public final class HitlAnalysisValidator {
    private HitlAnalysisValidator() {}

    public static void validate(AiAnalysisResponse response) {
        if (!"DAMAGE_DETECTED".equals(response.getAnalysisOutcome())) {
            throw new AiServiceException("Güvenilir hasar bulgusu belirlenemedi. Bu sonuç hasarsızlık anlamına gelmez; farklı bir fotoğraf veya fiziksel inceleme gerekir.");
        }
        if (!"hitl-v1".equals(response.getSchemaVersion()) || response.getModelVersion() == null
                || response.getModelVersion().isBlank() || response.getModelVersion().length() > 160
                || response.getDamageSeverity() != DamageSeverity.UNKNOWN
                || response.getImageWidth() == null || response.getImageHeight() == null
                || response.getImageWidth() <= 0 || response.getImageHeight() <= 0
                || (long) response.getImageWidth() * response.getImageHeight() > 24_000_000
                || response.getDetections() == null || response.getDetections().isEmpty()
                || response.getDetections().size() > 100 || response.getPartDetections() == null
                || response.getPartDetections().size() > 100) invalid();
        Set<String> parts = new HashSet<>();
        for (var part : response.getPartDetections()) {
            validateDetection(part, "part", response);
            if (part.getConfidence() >= .4) parts.add(part.getCode());
        }
        Set<DamageType> damageTypes = new HashSet<>();
        double maximum = 0;
        Set<VehiclePart> affected = new HashSet<>();
        for (var damage : response.getDetections()) {
            validateDetection(damage, "damage", response);
            damageTypes.add(DamageType.valueOf(damage.getCode()));
            maximum = Math.max(maximum, damage.getConfidence());
            if (damage.getAffectedPart() != null && damage.getAffectedPart() != VehiclePart.UNKNOWN) {
                if (!parts.contains(damage.getAffectedPart().name())) invalid();
                affected.add(damage.getAffectedPart());
            }
        }
        if (response.getConfidenceScore() == null || !Double.isFinite(response.getConfidenceScore())
                || Math.abs(maximum - response.getConfidenceScore()) > 1e-6
                || response.getDamageTypes() == null || !damageTypes.equals(new HashSet<>(response.getDamageTypes()))
                || response.getAffectedParts() == null
                || response.getRepairRecommendations() == null || response.getRepairRecommendations().isEmpty()) invalid();
        Set<DamageType> recommended = new HashSet<>();
        Set<VehiclePart> recommendationParts = new HashSet<>();
        for (var item : response.getRepairRecommendations()) {
            if (item == null || !damageTypes.contains(item.getDamageType())
                    || item.getRecommendedAction() != RepairAction.PROFESSIONAL_INSPECTION
                    || item.getPartReplacementRequired() != null
                    || item.getAffectedParts() == null) invalid();
            for (var part : item.getAffectedParts()) {
                if (part == null || !parts.contains(part.name()) || !hasSpatialEvidence(item.getDamageType(), part, response)) invalid();
                recommendationParts.add(part);
            }
            recommended.add(item.getDamageType());
        }
        if (!recommended.equals(damageTypes) || !recommendationParts.equals(new HashSet<>(response.getAffectedParts()))
                || !recommendationParts.containsAll(affected)) invalid();
    }

    private static boolean hasSpatialEvidence(DamageType type, VehiclePart part, AiAnalysisResponse response) {
        return response.getDetections().stream().filter(d -> type.name().equals(d.getCode())).anyMatch(d ->
                response.getPartDetections().stream().filter(p -> part.name().equals(p.getCode()) && p.getConfidence() >= .4)
                        .anyMatch(p -> {
                            var a=d.getBoundingBox(); var b=p.getBoundingBox();
                            double intersection=Math.max(0, Math.min(a.getX2(),b.getX2())-Math.max(a.getX1(),b.getX1()))
                                    * Math.max(0, Math.min(a.getY2(),b.getY2())-Math.max(a.getY1(),b.getY1()));
                            return intersection/((a.getX2()-a.getX1())*(a.getY2()-a.getY1())) >= .25;
                        }));
    }

    private static void validateDetection(DetectedObjectResponse detection, String task, AiAnalysisResponse response) {
        if (detection == null || detection.getConfidence() == null || !Double.isFinite(detection.getConfidence())
                || detection.getConfidence() < .25 || detection.getConfidence() > 1
                || !task.equals(detection.getTask())) invalid();
        try {
            var category = VisionClassCatalog.byName(detection.getLabel());
            if (!task.equals(category.task()) || !category.code().equals(detection.getCode())
                    || !Objects.equals(category.id(), detection.getClassId())) invalid();
        } catch (IllegalArgumentException exception) { invalid(); }
        var box = detection.getBoundingBox();
        if (box == null) invalid();
        Double[] coordinates = {box.getX1(), box.getY1(), box.getX2(), box.getY2()};
        for (Double coordinate : coordinates) if (coordinate == null || !Double.isFinite(coordinate)) invalid();
        if (box.getX1() < 0 || box.getY1() < 0 || box.getX2() <= box.getX1() || box.getY2() <= box.getY1()
                || box.getX2() > response.getImageWidth() || box.getY2() > response.getImageHeight()) invalid();
    }

    private static void invalid() {
        throw new AiServiceException("AI servisi sınıf veya kanıt sözleşmesine uymayan analiz verisi döndürdü.");
    }
}
