package com.gorkem.vehicle_inspector.service.report;

import com.gorkem.vehicle_inspector.dto.llm.DamageContext;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;

import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

public final class NearbyServicePromptBuilder {

    private NearbyServicePromptBuilder() {
    }

    public static String build(
            InspectionLlmRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException(
                    "Servis arama isteği boş olamaz."
            );
        }

        if (request.vehicle() == null) {
            throw new IllegalArgumentException(
                    "Araç bilgisi boş olamaz."
            );
        }

        List<DamageContext> damages =
                request.damages() != null
                        ? request.damages()
                        : Collections.emptyList();

        String damageText =
                damages.stream()
                        .filter(Objects::nonNull)
                        .map(
                                NearbyServicePromptBuilder
                                        ::formatDamage
                        )
                        .collect(
                                Collectors.joining("\n")
                        );

        if (damageText.isBlank()) {
            damageText =
                    "Kayıtlı onarım önerisi bulunmamaktadır.";
        }

        return """
                SENİN GÖREVİN

                Vehicle Inspector uygulaması için
                kullanıcının aracına ve tespit edilen
                hasara uygun servisleri bulmak amacıyla
                Google Places üzerinde kullanılacak
                arama sorguları üret.

                ÖNEMLİ KURALLAR

                Gerçek işletme veya servis adı uydurma.

                Belirli bir işletmenin var olduğunu
                iddia etme.

                Yalnızca Google Places üzerinde
                aranabilecek kısa ve anlamlı
                arama sorguları üret.

                Arama sorgularını oluştururken:

                - araç markasını
                - araç modelini
                - model yılını
                - hasar türünü
                - etkilenen parçayı
                - önerilen onarım işlemini
                - parça değişimi gerekip gerekmediğini

                dikkate al.

                Marka/model konusunda uzmanlaşmış
                servisleri bulmayı kolaylaştıracak
                sorgulara öncelik ver.

                Eğer parça değişimi gerekiyorsa
                uygun yedek parça aramasını da
                sorgular arasına ekle.

                Eğer hasar kaporta, boya, cam,
                far veya benzeri özel bir işlem
                gerektiriyorsa sorguyu buna göre
                özelleştir.

                <inspection_data>

                ARAÇ

                Marka: %s
                Model: %s
                Model yılı: %s

                KONUM

                Şehir: %s

                HASAR SEVİYESİ

                %s

                ONARIM BİLGİLERİ

                %s

                </inspection_data>

                ÇIKTI KURALLARI

                1. En fazla 4 arama sorgusu üret.

                2. Her sorgu birbirinden anlamlı
                   şekilde farklı olsun.

                3. Sorgular kısa ve Google Places
                   araması için uygun olsun.

                4. Şehir adını sorguya ekleme.
                   Konum ayrıca koordinat ile
                   filtrelenecektir.

                5. Gerçek işletme adı üretme.

                6. Kullanıcıya açıklama yazma.

                7. Yalnızca istenen JSON nesnesini
                   üret.

                JSON dışında hiçbir açıklama,
                Markdown veya kod bloğu üretme.
                """
                .formatted(
                        safe(request.vehicle().brand()),
                        safe(request.vehicle().model()),
                        safe(request.vehicle().modelYear()),
                        safe(request.city()),
                        safe(request.damageSeverity()),
                        damageText
                );
    }

    private static String formatDamage(
            DamageContext damage
    ) {
        String affectedParts =
                damage.affectedParts() == null
                        ? "Belirtilmemiş"
                        : damage.affectedParts()
                        .stream()
                        .filter(Objects::nonNull)
                        .map(Object::toString)
                        .collect(
                                Collectors.joining(", ")
                        );

        if (affectedParts.isBlank()) {
            affectedParts = "Belirtilmemiş";
        }

        return """
                - Hasar türü: %s
                  Önerilen işlem: %s
                  Parça değişimi gerekli: %s
                  Etkilenen parçalar: %s
                """
                .formatted(
                        safe(damage.damageType()),
                        safe(damage.recommendedAction()),
                        safe(
                                damage.partReplacementRequired()
                        ),
                        affectedParts
                );
    }

    private static String safe(
            Object value
    ) {
        if (value == null) {
            return "Belirtilmemiş";
        }

        String text =
                value.toString().trim();

        return text.isBlank()
                ? "Belirtilmemiş"
                : text;
    }
}