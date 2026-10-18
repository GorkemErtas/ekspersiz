package com.gorkem.vehicle_inspector.service.report;

import com.google.genai.types.GenerateContentResponse;
import com.gorkem.vehicle_inspector.dto.llm.DamageContext;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.VehicleContext;
import com.gorkem.vehicle_inspector.entity.DamageSeverity;
import com.gorkem.vehicle_inspector.entity.DamageType;
import com.gorkem.vehicle_inspector.entity.RepairAction;
import com.gorkem.vehicle_inspector.entity.VehiclePart;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class InspectionPriceWebGroundingTest {

    private static InspectionLlmRequest sample() {
        return new InspectionLlmRequest(
                new VehicleContext("Ford", "Mustang", 2016, 75000),
                "İzmir", LocalDate.of(2026, 10, 18), DamageSeverity.MODERATE,
                0.85, "Arka panelde çizik", List.of(
                    new DamageContext(DamageType.SCRATCH, RepairAction.FULL_PAINTING,
                            false, List.of(VehiclePart.QUARTER_PANEL))
                )
        );
    }

    @Test
    void includesRealGroundedEvidenceInPriceOnlyPrompt() {
        String web = "İzmir'de panel boyası: 12.000 TL (2026 tarihli örnek).";
        String prompt = InspectionReportPromptBuilder.build(sample(), web);
        assertTrue(prompt.contains(web));
        assertTrue(prompt.contains("10000 TL gibi sabit bir limite"));
        assertTrue(prompt.contains("Aynı fiziksel parçayı"));
        assertFalse(prompt.contains("fark en fazla 10000 TRY"));
    }

    @Test
    void withoutGroundingNeverClaimsLiveSearch() {
        String prompt = InspectionReportPromptBuilder.build(sample());
        assertTrue(prompt.contains("Doğrulanmış güncel web fiyat verisi yoktur"));
        assertTrue(prompt.contains("web'e baktığını iddia etme"));
    }

    @Test
    void searchPromptUsesVehicleCityAndRecommendedRepair() {
        String prompt = InspectionReportPromptBuilder.buildWebSearchPrompt(sample());
        assertTrue(prompt.contains("İzmir"));
        assertTrue(prompt.contains("Mustang"));
        assertTrue(prompt.contains("FULL_PAINTING"));
        assertTrue(prompt.contains("QUARTER_PANEL"));
        assertFalse(prompt.contains("75000"));
    }

    @Test
    void acceptsOnlyGoogleGroundedHttpsSources() {
        GenerateContentResponse grounded = GenerateContentResponse.fromJson("""
                {
                  "candidates": [{
                    "content": {"role": "model", "parts": [{"text": "İzmir boya fiyatı örnekleri"}]},
                    "groundingMetadata": {
                      "groundingChunks": [
                        {"web": {"uri": "https://example.org/izmir-boya", "title": "Example"}},
                        {"web": {"uri": "http://not-secure.test", "title": "Unsafe"}}
                      ]
                    }
                  }]
                }
                """);
        var extracted = GeminiInspectionReportService.extractWebEvidence(grounded);
        assertNotNull(extracted);
        assertEquals("İzmir boya fiyatı örnekleri", extracted.summary());
        assertEquals(List.of("https://example.org/izmir-boya"), extracted.sourceUrls());

        GenerateContentResponse ungrounded = GenerateContentResponse.fromJson("""
                {"candidates": [{
                  "content": {"role": "model", "parts": [{"text": "Kaynağı olmayan bir iddia"}]}
                }]}
                """);
        assertNull(GeminiInspectionReportService.extractWebEvidence(ungrounded));
    }
}
