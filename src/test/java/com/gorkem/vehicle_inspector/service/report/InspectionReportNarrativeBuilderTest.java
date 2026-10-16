package com.gorkem.vehicle_inspector.service.report;

import com.gorkem.vehicle_inspector.dto.llm.DamageContext;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.InspectionPriceEstimateResult;
import com.gorkem.vehicle_inspector.dto.llm.VehicleContext;
import com.gorkem.vehicle_inspector.entity.DamageSeverity;
import com.gorkem.vehicle_inspector.entity.DamageType;
import com.gorkem.vehicle_inspector.entity.RepairAction;
import com.gorkem.vehicle_inspector.entity.VehiclePart;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class InspectionReportNarrativeBuilderTest {

    private static final InspectionPriceEstimateResult PRICE =
            new InspectionPriceEstimateResult(
                    BigDecimal.valueOf(3000), BigDecimal.valueOf(6000),
                    "TRY", "Gemini işçilik ve parça maliyetini değerlendirdi.",
                    "Canlı fiyatlar kullanılmadı."
            );

    private static InspectionLlmRequest request(
            DamageSeverity severity, List<DamageContext> damages
    ) {
        return new InspectionLlmRequest(
                new VehicleContext("Toyota", "Corolla", 2021, 65000),
                "İzmir", LocalDate.of(2026, 10, 16), severity, 0.91,
                "ML'in verdiği özet", damages
        );
    }

    @Test
    void translatesDamageAndRepairWithoutAnotherLlmCall() {
        var inspection = request(DamageSeverity.MINOR, List.of(
                new DamageContext(
                        DamageType.SCRATCH, RepairAction.PAINT_TOUCH_UP,
                        false, List.of(VehiclePart.FRONT_BUMPER)
                )
        ));

        var result = InspectionReportNarrativeBuilder.build(inspection, PRICE);

        assertEquals("Araç Hasar Değerlendirme Raporu", result.title);
        assertTrue(result.summary.contains("hafif"));
        assertTrue(result.summary.contains("çizik"));
        assertTrue(result.damageDescription.contains("ön tampon"));
        assertTrue(result.repairRecommendation.contains("boya rötuşu"));
        assertFalse(result.repairRecommendation.contains("parça değişimi önerilmemiştir"));
        assertFalse(result.damageDescription.contains("ML'in verdiği özet"));
        assertTrue(result.disclaimer.contains("profesyonel ekspertiz"));
        assertEquals(PRICE.estimatedMinimumPrice(), result.estimatedMinimumPrice);
        assertEquals(PRICE.estimatedMaximumPrice(), result.estimatedMaximumPrice);
        assertEquals(PRICE.priceInformation(), result.priceInformation);
        assertEquals(PRICE.priceSourceDescription(), result.priceSourceDescription);
        assertEquals("TRY", result.currency);
    }

    @Test
    void multipleDamagesKeepTheirOwnActionsAndReplacementFlags() {
        var inspection = request(DamageSeverity.MODERATE, List.of(
                new DamageContext(
                        DamageType.SCRATCH, RepairAction.POLISHING,
                        false, List.of(VehiclePart.FRONT_DOOR, VehiclePart.UNKNOWN)
                ),
                new DamageContext(
                        DamageType.BROKEN_GLASS, RepairAction.GLASS_REPLACEMENT,
                        true, List.of(VehiclePart.REAR_WINDOW)
                )
        ));

        var report = InspectionReportNarrativeBuilder.build(inspection, PRICE);

        assertTrue(report.summary.contains("orta"));
        assertTrue(report.summary.contains("çizik"));
        assertTrue(report.summary.contains("cam kırığı"));
        assertTrue(report.damageDescription.contains("ön kapı"));
        assertTrue(report.damageDescription.contains("arka kapı camı"));
        assertFalse(report.damageDescription.contains("belirlenemeyen parça"));
        assertTrue(report.repairRecommendation.contains("pasta ve polisaj"));
        assertTrue(report.repairRecommendation.contains("cam değişimi"));
        assertFalse(report.repairRecommendation.contains("değişim gereksinimi de belirtildi"));
    }

    @Test
    void uncertainPartAndMissingDataAreHandledWithoutInventing() {
        var inspection = request(DamageSeverity.SEVERE, List.of(
                new DamageContext(DamageType.DENT, RepairAction.DENT_REPAIR,
                        false, List.of(VehiclePart.UNKNOWN))
        ));
        var report = InspectionReportNarrativeBuilder.build(inspection, PRICE);
        assertTrue(report.summary.contains("ağır"));
        assertTrue(report.damageDescription.contains("güvenle belirlenemedi"));
        assertTrue(report.repairRecommendation.contains("göçük onarımı"));

        var empty = InspectionReportNarrativeBuilder.build(
                request(DamageSeverity.UNKNOWN, null), PRICE);
        assertTrue(empty.summary.contains("belirsiz"));
        assertTrue(empty.repairRecommendation.contains("önerilemedi"));
    }

    @Test
    void fluentSingleDamageNarrativeKeepsVehicleAndDoesNotAddUnseenClaims() {
        var report = InspectionReportNarrativeBuilder.build(
                request(DamageSeverity.MINOR, List.of(
                        new DamageContext(DamageType.SCRATCH, RepairAction.PAINT_TOUCH_UP,
                                false, List.of(VehiclePart.FRONT_BUMPER)))),
                PRICE
        );

        assertEquals("Araç Hasar Değerlendirme Raporu", report.title);
        assertTrue(report.summary.startsWith("2021 model Toyota Corolla"));
        assertTrue(report.summary.contains(
                "ön tampon bölgesinde çizik tespit edildi"));
        assertTrue(report.damageDescription.startsWith(
                "Görüntülerin incelenmesi sonucunda"));
        assertTrue(report.damageDescription.endsWith(
                "fotoğraflarda görülebilen alanlarla sınırlıdır."));
        assertTrue(report.repairRecommendation.contains(
                "ön tampon bölgesindeki çizik için boya rötuşu öneriliyor"));
        assertTrue(report.repairRecommendation.contains("fiziksel inceleme"));
        assertFalse(report.damageDescription.contains("Tespit edilen hasar:"));
        assertFalse(report.repairRecommendation.contains("Önerilen işlem:"));
        assertFalse(report.damageDescription.contains("parça değişimi"));
    }

    @Test
    void multipleDifferentFindingsReadLikeParagraphsAndKeepPriceIdentical() {
        var report = InspectionReportNarrativeBuilder.build(
                request(DamageSeverity.MODERATE, List.of(
                        new DamageContext(DamageType.SCRATCH, RepairAction.POLISHING,
                                false, List.of(VehiclePart.FRONT_DOOR)),
                        new DamageContext(DamageType.DENT, RepairAction.DENT_REPAIR,
                                false, List.of(VehiclePart.QUARTER_PANEL)))),
                PRICE
        );
        assertTrue(report.summary.contains("ön kapı bölgesinde çizik"));
        assertTrue(report.summary.contains("arka yan panel bölgesinde göçük"));
        assertTrue(report.damageDescription.contains("Ayrıca"));
        assertTrue(report.repairRecommendation.contains("göçük onarımı"));
        assertEquals(PRICE.estimatedMinimumPrice(), report.estimatedMinimumPrice);
        assertEquals(PRICE.estimatedMaximumPrice(), report.estimatedMaximumPrice);
        assertEquals(PRICE.priceInformation(), report.priceInformation);
    }

    @Test
    void mapsEveryDamagePartAndRepairEnumWithoutFallbackOrException() {
        for (var type : DamageType.values()) {
            var report = InspectionReportNarrativeBuilder.build(
                    request(DamageSeverity.MODERATE,
                            List.of(new DamageContext(type, RepairAction.PART_REPAIR,
                                    false, List.of(VehiclePart.HOOD)))),
                    PRICE
            );
            assertNotNull(report.damageDescription);
            assertFalse(report.damageDescription.isBlank());
        }
        for (var action : RepairAction.values()) {
            var report = InspectionReportNarrativeBuilder.build(
                    request(DamageSeverity.MODERATE,
                            List.of(new DamageContext(DamageType.CRACK, action,
                                    false, List.of(VehiclePart.HOOD)))),
                    PRICE
            );
            assertNotNull(report.repairRecommendation);
            assertFalse(report.repairRecommendation.isBlank());
        }
        for (var part : VehiclePart.values()) {
            var report = InspectionReportNarrativeBuilder.build(
                    request(DamageSeverity.MODERATE,
                            List.of(new DamageContext(DamageType.CRACK,
                                    RepairAction.PART_REPAIR, false, List.of(part)))),
                    PRICE
            );
            assertFalse(report.damageDescription.isBlank());
        }
    }

    @Test
    void pricingPromptRequestsOnlyFiveFieldsAndPreservesCostFactors() {
        var prompt = InspectionReportPromptBuilder.build(request(
                DamageSeverity.MODERATE,
                List.of(new DamageContext(DamageType.CRACK,
                        RepairAction.PART_REPAIR, true,
                        List.of(VehiclePart.REAR_BUMPER)))));
        assertTrue(prompt.contains("estimatedMinimumPrice"));
        assertTrue(prompt.contains("estimatedMaximumPrice"));
        assertTrue(prompt.contains("priceInformation"));
        assertTrue(prompt.contains("priceSourceDescription"));
        assertTrue(prompt.contains("currency"));
        assertTrue(prompt.contains("Toyota"));
        assertTrue(prompt.contains("Corolla"));
        assertTrue(prompt.contains("İzmir"));
        assertTrue(prompt.contains("65000"));
        assertTrue(prompt.contains("PART_REPAIR"));
        assertTrue(prompt.contains("REAR_BUMPER"));
        assertTrue(prompt.contains("gerçek zamanlı"));
        assertTrue(prompt.contains("TOPLAM ONARIM FİYATI"));
        assertTrue(prompt.contains("ML'in verdiği özet"));
        assertTrue(prompt.contains("0.91"));
        assertTrue(prompt.contains("ML güven skoru"));
    }
}
