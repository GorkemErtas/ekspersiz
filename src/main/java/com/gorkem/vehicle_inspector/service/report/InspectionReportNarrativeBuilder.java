package com.gorkem.vehicle_inspector.service.report;

import com.gorkem.vehicle_inspector.dto.llm.DamageContext;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.InspectionPriceEstimateResult;
import com.gorkem.vehicle_inspector.dto.llm.LlmInspectionReportResult;
import com.gorkem.vehicle_inspector.entity.DamageSeverity;
import com.gorkem.vehicle_inspector.entity.DamageType;
import com.gorkem.vehicle_inspector.entity.RepairAction;
import com.gorkem.vehicle_inspector.entity.VehiclePart;

import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * Stable, local Turkish report narrative from the already-validated ML results.
 * No model/API call, speculative diagnoses, or prices are generated here.
 */
public final class InspectionReportNarrativeBuilder {

    private static final String DISCLAIMER =
            "Bu rapor yalnızca yüklenen fotoğraflardaki görünür alanların otomatik "
            + "hasar değerlendirmesine dayanır. Mekanik kontrol veya profesyonel "
            + "ekspertiz yerine geçmez. Onarım fiyatı yapay zekânın yaklaşık "
            + "tahminidir; güncel servis teklifi değildir. Kesin onarım yöntemi "
            + "ve bedeli fiziksel inceleme sonucunda belirlenmelidir.";

    private InspectionReportNarrativeBuilder() {
    }

    public static LlmInspectionReportResult build(
            InspectionLlmRequest request,
            InspectionPriceEstimateResult price
    ) {
        Objects.requireNonNull(request, "Rapor verisi boş olamaz.");
        Objects.requireNonNull(price, "Fiyat tahmini boş olamaz.");

        List<DamageContext> damages = request.damages() == null
                ? List.of()
                : request.damages().stream().filter(Objects::nonNull).toList();

        LlmInspectionReportResult result = new LlmInspectionReportResult();
        result.title = "Araç Hasar İnceleme Raporu";
        result.summary = buildSummary(request.damageSeverity(), damages);
        result.damageDescription = buildDamageDescription(damages);
        result.repairRecommendation = buildRepairRecommendation(damages);
        result.estimatedMinimumPrice = price.estimatedMinimumPrice();
        result.estimatedMaximumPrice = price.estimatedMaximumPrice();
        result.currency = price.currency();
        result.priceInformation = price.priceInformation();
        result.priceSourceDescription = price.priceSourceDescription();
        result.disclaimer = DISCLAIMER;
        return result;
    }

    private static String buildSummary(
            DamageSeverity severity, List<DamageContext> damages
    ) {
        String heading = "Görüntüye dayalı değerlendirmede hasar seviyesi "
                + severityName(severity) + " olarak sınıflandırılmıştır.";
        if (damages.isEmpty()) {
            return heading + " Ayrıntılı hasar ve onarım bilgisi belirlenemedi. "
                    + "Sonuç yalnızca fotoğraflarda görünen alanlarla sınırlıdır.";
        }
        String types = damages.stream()
                .map(DamageContext::damageType)
                .filter(Objects::nonNull)
                .map(InspectionReportNarrativeBuilder::damageName)
                .distinct()
                .collect(Collectors.joining(", "));
        String details = types.isBlank()
                ? ""
                : " Tespit edilen hasar türleri: " + types + ".";
        return heading + details
                + " Sonuç yalnızca fotoğraflarda görünen alanlarla sınırlıdır.";
    }

    private static String buildDamageDescription(List<DamageContext> damages) {
        if (damages.isEmpty()) {
            return "Görüntüdeki hasar türü ve etkilenen araç parçaları "
                    + "ayrıntılı olarak belirlenemedi.";
        }
        return damages.stream()
                .map(damage -> {
                    String description = "Tespit edilen hasar: "
                            + damageName(damage.damageType()) + ".";
                    String parts = partList(damage.affectedParts());
                    return description + (parts.isEmpty()
                            ? " Etkilenen araç parçası güvenle belirlenemedi."
                            : " Etkilenen parçalar: " + parts + ".");
                })
                .collect(Collectors.joining("\n"));
    }

    private static String buildRepairRecommendation(List<DamageContext> damages) {
        if (damages.isEmpty()) {
            return "Analiz verilerinde onarım işlemi belirtilmemiştir. "
                    + "Uygun yöntem için araç fiziksel olarak incelenmelidir.";
        }
        return damages.stream()
                .map(damage -> {
                    String prefix = damageName(damage.damageType()) + " için "
                            + "önerilen işlem: "
                            + repairName(damage.recommendedAction()) + ".";
                    String replacement = Boolean.TRUE.equals(
                            damage.partReplacementRequired())
                            ? " Analiz sonucunda parça değişimi önerilmiştir."
                            : " Analizde parça değişimi önerilmemiştir.";
                    return prefix + replacement;
                })
                .collect(Collectors.joining("\n"));
    }

    private static String partList(List<VehiclePart> parts) {
        if (parts == null) {
            return "";
        }
        return parts.stream()
                .filter(Objects::nonNull)
                .filter(part -> part != VehiclePart.UNKNOWN)
                .map(InspectionReportNarrativeBuilder::partName)
                .distinct()
                .collect(Collectors.joining(", "));
    }

    private static String severityName(DamageSeverity severity) {
        if (severity == null) {
            return "belirsiz";
        }
        return switch (severity) {
            case MINOR -> "hafif";
            case MODERATE -> "orta";
            case SEVERE -> "ağır";
            case NONE -> "görünür hasar yok";
            case UNKNOWN -> "belirsiz";
        };
    }

    private static String damageName(DamageType type) {
        if (type == null) {
            return "belirlenemeyen hasar";
        }
        return switch (type) {
            case NO_VISIBLE_DAMAGE -> "görünür hasar yok";
            case SCRATCH -> "çizik";
            case PAINT_DAMAGE -> "boya hasarı";
            case DENT -> "göçük";
            case CRACK -> "çatlak";
            case BROKEN_PART -> "kırık parça";
            case BROKEN_GLASS -> "cam kırığı";
            case DEFORMATION -> "deformasyon";
        };
    }

    private static String repairName(RepairAction action) {
        if (action == null) {
            return "belirlenemedi";
        }
        return switch (action) {
            case NO_ACTION -> "onarım önerilmiyor";
            case POLISHING -> "pasta ve polisaj";
            case PAINT_TOUCH_UP -> "boya rötuşu";
            case FULL_PAINTING -> "boyama";
            case PAINTLESS_DENT_REPAIR -> "boyasız göçük düzeltme";
            case DENT_REPAIR -> "göçük onarımı";
            case PLASTIC_REPAIR -> "plastik parça onarımı";
            case PART_REPAIR -> "parça onarımı";
            case PART_REPLACEMENT -> "parça değişimi";
            case GLASS_REPAIR -> "cam onarımı";
            case GLASS_REPLACEMENT -> "cam değişimi";
            case HEADLIGHT_REPAIR -> "far onarımı";
            case HEADLIGHT_REPLACEMENT -> "far değişimi";
        };
    }

    private static String partName(VehiclePart part) {
        return switch (part) {
            case UNKNOWN -> "belirlenemeyen parça";
            case FRONT_BUMPER -> "ön tampon";
            case REAR_BUMPER -> "arka tampon";
            case FRONT_DOOR -> "ön kapı";
            case REAR_DOOR -> "arka kapı";
            case FRONT_WHEEL -> "ön tekerlek";
            case REAR_WHEEL -> "arka tekerlek";
            case FRONT_WINDOW -> "ön kapı camı";
            case REAR_WINDOW -> "arka kapı camı";
            case WINDSHIELD -> "ön cam";
            case REAR_WINDSHIELD -> "arka cam";
            case FENDER -> "çamurluk";
            case QUARTER_PANEL -> "arka yan panel";
            case ROCKER_PANEL -> "marşpiyel";
            case GRILLE -> "ön ızgara";
            case HEADLIGHT -> "far";
            case TAIL_LIGHT -> "arka stop lambası";
            case HOOD -> "kaput";
            case LICENSE_PLATE -> "plaka";
            case MIRROR -> "ayna";
            case ROOF -> "tavan";
            case TRUNK -> "bagaj kapağı";
        };
    }
}
