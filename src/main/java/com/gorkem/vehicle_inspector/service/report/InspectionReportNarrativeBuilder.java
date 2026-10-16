package com.gorkem.vehicle_inspector.service.report;

import com.gorkem.vehicle_inspector.dto.llm.DamageContext;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.InspectionPriceEstimateResult;
import com.gorkem.vehicle_inspector.dto.llm.LlmInspectionReportResult;
import com.gorkem.vehicle_inspector.entity.DamageSeverity;
import com.gorkem.vehicle_inspector.entity.DamageType;
import com.gorkem.vehicle_inspector.entity.RepairAction;
import com.gorkem.vehicle_inspector.entity.VehiclePart;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * Naturally worded Turkish inspection narrative based strictly on existing
 * structured ML results. No Gemini call and no invented defects or repairs.
 * Prices and pricing explanations remain untouched and are supplied by Gemini.
 */
public final class InspectionReportNarrativeBuilder {

    private static final int SUMMARY_LIMIT = 1500;
    private static final int DESCRIPTION_LIMIT = 3000;

    private static final String DISCLAIMER =
            "Bu rapor, yalnızca yüklenen fotoğraflarda görülebilen hasarların "
            + "otomatik değerlendirmesine dayanır. Mekanik kontrol veya "
            + "profesyonel ekspertiz yerine geçmez. Belirtilen fiyat aralığı "
            + "yapay zekâ tarafından oluşturulmuş yaklaşık bir tahmindir; "
            + "güncel bir servis teklifi değildir. Kesin onarım işlemi ve "
            + "maliyeti, aracın fiziksel incelemesiyle belirlenmelidir.";

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
                : request.damages().stream()
                        .filter(Objects::nonNull)
                        .filter(damage -> damage.damageType() != DamageType.NO_VISIBLE_DAMAGE)
                        .toList();

        LlmInspectionReportResult result = new LlmInspectionReportResult();
        result.title = "Araç Hasar Değerlendirme Raporu";
        result.summary = buildSummary(request, damages);
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
            InspectionLlmRequest request, List<DamageContext> damages
    ) {
        String subject = vehicleDescription(request);
        if (damages.isEmpty()) {
            return subject + " için yapılan fotoğraf incelemesinde "
                    + "ayrıntılı bir hasar bulgusu belirlenemedi. "
                    + "Görünür hasar seviyesi "
                    + severityName(request.damageSeverity())
                    + " olarak kaydedildi.";
        }
        String findings = damages.stream()
                .map(InspectionReportNarrativeBuilder::finding)
                .distinct()
                .collect(Collectors.joining(", "));
        return fit(
                subject + " için gönderilen fotoğraflarda "
                + findings + " tespit edildi. "
                + "Bulgulara göre görünür hasar seviyesi "
                + severityName(request.damageSeverity())
                + " olarak değerlendirildi.",
                SUMMARY_LIMIT
        );
    }

    private static String buildDamageDescription(List<DamageContext> damages) {
        if (damages.isEmpty()) {
            return "Fotoğraf analizinde hasarın türü ve konumu hakkında "
                    + "ayrıntılı bilgi elde edilemedi. "
                    + "Belirlenmeyen araç parçaları veya hasar türleri "
                    + "hakkında ek varsayımda bulunulmadı.";
        }
        List<String> sentences = new ArrayList<>();
        for (int i = 0; i < damages.size(); i++) {
            DamageContext damage = damages.get(i);
            String location = partList(damage.affectedParts());
            String intro = i == 0
                    ? "Görüntülerin incelenmesi sonucunda "
                    : "Ayrıca ";
            String sentence = location.isBlank()
                    ? intro + damageName(damage.damageType())
                        + " tespit edildi. Etkilenen araç parçası "
                        + "güvenle belirlenemedi."
                    : intro + location + " bölgesinde "
                        + damageName(damage.damageType()) + " tespit edildi.";
            sentences.add(sentence);
        }
        sentences.add(
                "Bu değerlendirme fotoğraflarda görülebilen alanlarla sınırlıdır."
        );
        return joinWithinLimit(sentences, DESCRIPTION_LIMIT);
    }

    private static String buildRepairRecommendation(List<DamageContext> damages) {
        if (damages.isEmpty()) {
            return "Analiz sonucunda belirli bir onarım işlemi önerilemedi. "
                    + "Uygun yöntemin belirlenmesi için aracın fiziksel olarak "
                    + "incelenmesi gerekir.";
        }
        List<String> sentences = new ArrayList<>();
        for (DamageContext damage : damages) {
            String location = partList(damage.affectedParts());
            String subject = location.isBlank()
                    ? damageName(damage.damageType())
                    : location + " bölgesindeki " + damageName(damage.damageType());
            RepairAction action = damage.recommendedAction();
            String sentence = action == null || action == RepairAction.NO_ACTION
                    ? subject + " için analizde bir onarım işlemi belirtilmedi."
                    : subject + " için " + repairName(action)
                        + " öneriliyor.";
            if (Boolean.TRUE.equals(damage.partReplacementRequired())
                    && action != RepairAction.PART_REPLACEMENT
                    && action != RepairAction.GLASS_REPLACEMENT
                    && action != RepairAction.HEADLIGHT_REPLACEMENT) {
                sentence += " Aynı parça için değişim gereksinimi de belirtildi.";
            }
            sentences.add(sentence);
        }
        sentences.add("Önerilen işlemin uygulanabilirliği ve kapsamı, "
                + "serviste yapılacak fiziksel inceleme sonrasında netleştirilmelidir.");
        return joinWithinLimit(sentences, DESCRIPTION_LIMIT);
    }

    private static String vehicleDescription(InspectionLlmRequest request) {
        if (request.vehicle() == null) {
            return "Araç";
        }
        String brand = clean(request.vehicle().brand());
        String model = clean(request.vehicle().model());
        String name = (brand + " " + model).trim();
        Integer year = request.vehicle().modelYear();
        if (year != null && year >= 1900 && year <= 2100) {
            name = year + " model " + name;
        }
        return name.isBlank() ? "Araç" : name;
    }

    private static String clean(String raw) {
        return raw == null ? "" : raw.replaceAll("[\\p{Cntrl}]+", " ").trim();
    }

    private static String finding(DamageContext damage) {
        String location = partList(damage.affectedParts());
        return location.isBlank()
                ? damageName(damage.damageType())
                : location + " bölgesinde " + damageName(damage.damageType());
    }

    private static String partList(List<VehiclePart> parts) {
        if (parts == null || parts.isEmpty()) {
            return "";
        }
        List<String> names = new ArrayList<>(
                parts.stream()
                        .filter(Objects::nonNull)
                        .filter(part -> part != VehiclePart.UNKNOWN)
                        .map(InspectionReportNarrativeBuilder::partName)
                        .collect(Collectors.toCollection(LinkedHashSet::new))
        );
        if (names.isEmpty()) {
            return "";
        }
        if (names.size() == 1) {
            return names.getFirst();
        }
        return String.join(", ", names.subList(0, names.size() - 1))
                + " ve " + names.getLast();
    }

    private static String joinWithinLimit(List<String> sentences, int limit) {
        StringBuilder result = new StringBuilder();
        for (String sentence : sentences) {
            int addition = sentence.length() + (result.isEmpty() ? 0 : 1);
            if (result.length() + addition > limit) {
                break;
            }
            if (!result.isEmpty()) {
                result.append(' ');
            }
            result.append(sentence);
        }
        return result.toString();
    }

    private static String fit(String value, int limit) {
        if (value.length() <= limit) {
            return value;
        }
        // Avoid a database length violation for unusually many ML findings.
        return value.substring(0, Math.max(0, limit - 1)).stripTrailing() + "…";
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
            return "türü belirlenemeyen hasar";
        }
        return switch (type) {
            case NO_VISIBLE_DAMAGE -> "görünür hasar yok";
            case SCRATCH -> "çizik";
            case PAINT_DAMAGE -> "boya hasarı";
            case DENT -> "göçük";
            case CRACK -> "çatlak";
            case BROKEN_PART -> "parça kırığı";
            case BROKEN_GLASS -> "cam kırığı";
            case DEFORMATION -> "deformasyon";
        };
    }

    private static String repairName(RepairAction action) {
        return switch (action) {
            case NO_ACTION -> "onarım önerilmiyor";
            case POLISHING -> "pasta ve polisaj işlemi";
            case PAINT_TOUCH_UP -> "boya rötuşu";
            case FULL_PAINTING -> "boyama işlemi";
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
