package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.llm.*;
import com.gorkem.vehicle_inspector.entity.DamageSeverity;
import com.gorkem.vehicle_inspector.service.report.InspectionReportNarrativeBuilder;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;

class GeminiReportNarrativeTest {
    @Test void reportPreservesVisibleDescriptionsRepairUncertaintyAndExistingPrice() {
        var findings = GeminiVisionFixtures.unknown().getVisualFindings();
        var request = new InspectionLlmRequest(new VehicleContext("Test", "Car", 2024, 1000), "İzmir",
                LocalDate.of(2026, 10, 25), DamageSeverity.UNKNOWN, null, "Fotoğraf yorumu", List.of(), findings);
        var price = new InspectionPriceEstimateResult(BigDecimal.valueOf(1000), BigDecimal.valueOf(2000),
                "TRY", "Yaklaşık piyasa aralığı", "Kesin teklif değildir");
        var result = InspectionReportNarrativeBuilder.build(request, price);
        assertTrue(result.damageDescription.contains(findings.getFirst().description()));
        assertTrue(result.repairRecommendation.contains(findings.getFirst().repairNotes()));
        assertTrue(result.repairRecommendation.contains("fiziksel incelemeyle"));
        assertEquals(price.estimatedMinimumPrice(), result.estimatedMinimumPrice);
        assertTrue(result.disclaimer.contains("profesyonel ekspertiz yerine geçmez"));
    }
}
