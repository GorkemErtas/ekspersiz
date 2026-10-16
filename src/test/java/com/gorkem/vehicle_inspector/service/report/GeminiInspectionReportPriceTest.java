package com.gorkem.vehicle_inspector.service.report;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.dto.llm.InspectionPriceEstimateResult;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

class GeminiInspectionReportPriceTest {

    private static InspectionPriceEstimateResult estimate(
            BigDecimal minimum, BigDecimal maximum, String currency,
            String priceInformation, String priceSource
    ) {
        return new InspectionPriceEstimateResult(
                minimum, maximum, currency, priceInformation, priceSource
        );
    }

    @Test
    void parsesOnlyTheFivePricingFieldsFromGeminiJson() throws Exception {
        String json = """
                {
                  "estimatedMinimumPrice": 2500.00,
                  "estimatedMaximumPrice": 4500.00,
                  "currency": "TRY",
                  "priceInformation": "Şehir ve işçilik maliyetleri dikkate alındı.",
                  "priceSourceDescription": "Canlı fiyat verisi kullanılmadı."
                }
                """;

        var parsed = new ObjectMapper().readValue(
                json, InspectionPriceEstimateResult.class
        );
        assertEquals(0, BigDecimal.valueOf(2500).compareTo(
                parsed.estimatedMinimumPrice()));
        assertEquals("TRY", parsed.currency());
        assertEquals("Canlı fiyat verisi kullanılmadı.",
                parsed.priceSourceDescription());
        assertEquals(0, BigDecimal.valueOf(4500).compareTo(
                GeminiInspectionReportService.validatePrice(parsed)
                        .estimatedMaximumPrice()));
    }

    @Test
    void preservesExistingMaximumTenThousandLiraPriceSpreadPolicy() {
        var price = estimate(
                BigDecimal.valueOf(2500),
                BigDecimal.valueOf(45000),
                "try", "Fiyat açıklaması", "Web fiyatı kullanılmadı"
        );
        var normalized = GeminiInspectionReportService.validatePrice(price);
        assertEquals(BigDecimal.valueOf(12500), normalized.estimatedMaximumPrice());
        assertEquals("TRY", normalized.currency());
        assertEquals("Fiyat açıklaması", normalized.priceInformation());
    }

    @Test
    void rejectsInvalidPricesAndMissingSourceDescriptions() {
        var valid = estimate(
                BigDecimal.valueOf(1500), BigDecimal.valueOf(3500),
                "TRY", "Açıklama", "Kaynak açıklaması"
        );
        assertEquals(valid.estimatedMaximumPrice(),
                GeminiInspectionReportService.validatePrice(valid)
                        .estimatedMaximumPrice());

        assertThrows(IllegalStateException.class, () ->
                GeminiInspectionReportService.validatePrice(
                        estimate(BigDecimal.valueOf(-1), BigDecimal.TEN,
                                "TRY", "Açıklama", "Kaynak")));
        assertThrows(IllegalStateException.class, () ->
                GeminiInspectionReportService.validatePrice(
                        estimate(BigDecimal.TEN, BigDecimal.ONE,
                                "TRY", "Açıklama", "Kaynak")));
        assertThrows(IllegalStateException.class, () ->
                GeminiInspectionReportService.validatePrice(
                        estimate(BigDecimal.ONE, BigDecimal.TEN,
                                "USD", "Açıklama", "Kaynak")));
        assertThrows(IllegalStateException.class, () ->
                GeminiInspectionReportService.validatePrice(
                        estimate(BigDecimal.ONE, BigDecimal.TEN,
                                "TRY", " ", "Kaynak")));
        assertThrows(IllegalStateException.class, () ->
                GeminiInspectionReportService.validatePrice(
                        estimate(BigDecimal.ONE, BigDecimal.TEN,
                                "TRY", "Açıklama", null)));
        assertThrows(IllegalStateException.class, () ->
                GeminiInspectionReportService.validatePrice(
                        estimate(BigDecimal.ONE, null,
                                "TRY", "Açıklama", "Kaynak")));
    }
}
