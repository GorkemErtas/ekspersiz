package com.gorkem.vehicle_inspector;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.dto.response.AiAnalysisResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.AiServiceException;
import com.gorkem.vehicle_inspector.service.HitlAnalysisValidator;
import com.gorkem.vehicle_inspector.service.VisionClassCatalog;
import org.junit.jupiter.api.Test;
import java.nio.file.Files;
import java.nio.file.Path;
import static org.junit.jupiter.api.Assertions.*;

class HitlAnalysisValidatorTest {
    private final ObjectMapper mapper = new ObjectMapper();

    AiAnalysisResponse response() throws Exception {
        var scratch = VisionClassCatalog.byName("Scratch");
        var hood = VisionClassCatalog.byName("Hood");
        String json = """
                {"schemaVersion":"hitl-v1","modelVersion":"unit-test","analysisOutcome":"DAMAGE_DETECTED",
                 "imageWidth":640,"imageHeight":480,"damageSeverity":"UNKNOWN","confidenceScore":0.8,
                 "damageTypes":["SCRATCH"],"affectedParts":["HOOD"],
                 "detections":[{"classId":%d,"code":"SCRATCH","task":"damage","label":"Scratch",
                   "confidence":0.8,"affectedPart":"HOOD","boundingBox":{"x1":20,"y1":20,"x2":50,"y2":50}}],
                 "partDetections":[{"classId":%d,"code":"HOOD","task":"part","label":"Hood",
                   "confidence":0.9,"boundingBox":{"x1":0,"y1":0,"x2":100,"y2":100}}],
                 "repairRecommendations":[{"damageType":"SCRATCH","recommendedAction":"PROFESSIONAL_INSPECTION",
                   "partReplacementRequired":null,"affectedParts":["HOOD"]}]}
                """.formatted(scratch.id(),hood.id());
        return mapper.readValue(json,AiAnalysisResponse.class);
    }

    @Test void originalClassIdentityAndUnknownSeverityAreAccepted() throws Exception {
        var result = response();
        assertDoesNotThrow(() -> HitlAnalysisValidator.validate(result));
        assertEquals("Scratch", result.getDetections().getFirst().getLabel());
        assertEquals(DamageSeverity.UNKNOWN,result.getDamageSeverity());
    }

    @Test void inconclusiveAndNoDamageClaimsAreRejected() throws Exception {
        var result=response();result.setAnalysisOutcome("INCONCLUSIVE");
        assertThrows(AiServiceException.class,()->HitlAnalysisValidator.validate(result));
        result.setAnalysisOutcome("DAMAGE_DETECTED");result.setDamageSeverity(DamageSeverity.NONE);
        assertThrows(AiServiceException.class,()->HitlAnalysisValidator.validate(result));
    }

    @Test void inventedConfidenceClassesOrReplacementAreRejected() throws Exception {
        var result=response();result.setConfidenceScore(.99);
        final var wrongConfidence=result;
        assertThrows(AiServiceException.class,()->HitlAnalysisValidator.validate(wrongConfidence));
        result=response();result.getDetections().getFirst().setLabel("BROKEN_GLASS");
        final var wrongClass=result;
        assertThrows(AiServiceException.class,()->HitlAnalysisValidator.validate(wrongClass));
        result=response();result.getRepairRecommendations().getFirst().setPartReplacementRequired(true);
        final var wrongRepair=result;
        assertThrows(AiServiceException.class,()->HitlAnalysisValidator.validate(wrongRepair));
    }

    @Test void allGeneratedCatalogsAgreeAndHistoricalEnumsRemainReadable() throws Exception {
        var catalog=mapper.readTree(Files.readString(Path.of("ai-service/app/vision/classes.json")));
        var dart=Files.readString(Path.of("mobile/lib/features/inspection/models/vision_class_catalog.dart"));
        assertEquals(29,catalog.get("categories").size());
        for (var c:catalog.get("categories")) {
            var entry=VisionClassCatalog.byName(c.get("name").asText());
            assertEquals(c.get("id").asInt(),entry.id());
            assertEquals(c.get("code").asText(),entry.code());
            assertEquals(c.get("display_tr").asText(),entry.turkishName());
            assertTrue(dart.contains("'"+entry.originalName()+"':"));
            if (entry.task().equals("damage")) assertNotNull(DamageType.valueOf(entry.code()));
            else assertNotNull(VehiclePart.valueOf(entry.code()));
        }
        assertEquals(DamageType.CRACK,DamageType.valueOf("CRACK"));
        assertEquals(VehiclePart.REAR_BUMPER,VehiclePart.valueOf("REAR_BUMPER"));
        assertNotEquals(VehiclePart.REAR_BUMPER,VehiclePart.BACK_BUMPER);
    }
}
