import 'damage_inspection.dart';
import 'inspection_labels.dart';

/// Shared screen/PDF presentation. Never changes stored analysis or report data.
class InspectionReportContent {
  InspectionReportContent(this.inspection);

  final DamageInspection inspection;

  bool get noVisibleDamage =>
      inspection.isCompleted &&
      !inspection.needsMorePhotos &&
      inspection.damageSeverity == 'NONE';

  String get title {
    if (inspection.needsMorePhotos) {
      return inspection.analysisOutcome == 'INCONCLUSIVE'
          ? 'Sonuç Belirsiz'
          : 'Ek Fotoğraf Gerekli';
    }
    if (inspection.isProcessing) return 'Analiz Devam Ediyor';
    if (inspection.isFailed) return 'Analiz Tamamlanamadı';
    if (!inspection.isCompleted) return 'Analiz Bekliyor';
    return InspectionLabels.severity(inspection.damageSeverity);
  }

  String get priceTitle => inspection.isInspectionOnly
      ? 'Tahmini Fiziksel İnceleme Maliyeti'
      : 'Tahmini Onarım Maliyeti';

  bool get hasPrice {
    final report = inspection.report;
    return report != null &&
        report.estimatedMinimumPrice.isFinite &&
        report.estimatedMaximumPrice.isFinite &&
        report.estimatedMinimumPrice >= 0 &&
        report.estimatedMaximumPrice > 0 &&
        report.estimatedMaximumPrice >= report.estimatedMinimumPrice;
  }

  String get price {
    final report = inspection.report;
    if (!hasPrice || report == null) {
      return noVisibleDamage ? 'Maliyet hesaplanmadı' : 'Henüz belirlenmedi';
    }
    return '${money(report.estimatedMinimumPrice)} – '
        '${money(report.estimatedMaximumPrice)} ${report.currency}';
  }

  String get disclaimer =>
      inspection.report?.disclaimer.trim().isNotEmpty == true
      ? inspection.report!.disclaimer.trim()
      : 'Bu değerlendirme yalnızca fotoğraflarda görünen alanlarla sınırlıdır; '
            'mekanik veya profesyonel ekspertiz garantisi değildir. '
            'Kesin işlem ve maliyet fiziksel incelemeyle belirlenir.';

  List<ReportFinding> get findings {
    if (noVisibleDamage) return const [];
    final groups = <String, ReportFinding>{};
    final coveredTypes = <String>{};
    final coveredParts = <String>{};
    ReportFinding group(String part) => groups.putIfAbsent(
      part,
      () => ReportFinding(part: InspectionLabels.label(part) ?? part),
    );

    for (final finding in inspection.visualFindings) {
      final row = group(finding.affectedPart);
      row.damageTypes.add(
        InspectionLabels.label(finding.damageType) ?? finding.damageType,
      );
      row.observations.addAll(uniqueText([finding.description]));
      if (finding.severity != inspection.damageSeverity) {
        row.observations.add(InspectionLabels.severity(finding.severity));
      }
      row.repairs.addAll(uniqueText([finding.repairNotes]));
      row.repairs.add(switch (finding.replacementAssessment) {
        'POSSIBLE' =>
          'Parça değişimi gerekebilir; fiziksel incelemeyle netleşir.',
        'NOT_INDICATED' =>
          'Fotoğraflarda parça değişimi gereksinimi görülmedi; fiziksel inceleme gerekir.',
        _ => 'Parça değişimi gereksinimi fiziksel incelemeyle belirlenecek.',
      });
      coveredTypes.add(finding.damageType);
      coveredParts.add(finding.affectedPart);
    }

    for (final recommendation in inspection.repairRecommendations) {
      // Only keep relationships present in the contract; never pair unrelated
      // historical damage types and parts by their array index.
      final parts = recommendation.affectedParts;
      final key = parts.length == 1 ? parts.single : parts.join(', ');
      final row = groups.putIfAbsent(
        key,
        () => ReportFinding(
          part: parts.isEmpty
              ? 'Konumu Belirlenemeyen Bulgu'
              : parts.map((p) => InspectionLabels.label(p) ?? p).join(', '),
        ),
      );
      row.damageTypes.add(
        InspectionLabels.label(recommendation.damageType) ??
            recommendation.damageType,
      );
      final hasVisualRepair = inspection.visualFindings.any(
        (finding) =>
            parts.contains(finding.affectedPart) &&
            finding.damageType == recommendation.damageType &&
            finding.repairNotes.trim().isNotEmpty,
      );
      // The generic fallback adds no repair detail to existing visual notes.
      if (recommendation.recommendedAction != 'PROFESSIONAL_INSPECTION' ||
          !hasVisualRepair) {
        row.repairs.add(
          InspectionLabels.label(recommendation.recommendedAction) ??
              recommendation.recommendedAction,
        );
      }
      if (recommendation.partReplacementRequired == true) {
        row.repairs.add(
          'Analizde parça değişimi önerildi; fiziksel incelemeyle doğrulanmalıdır.',
        );
      } else if (recommendation.partReplacementRequired == null &&
          !hasVisualRepair) {
        row.repairs.add(
          'Parça değişimi gereksinimi fiziksel incelemeyle belirlenecek.',
        );
      }
      coveredTypes.add(recommendation.damageType);
      coveredParts.addAll(parts);
    }

    final extraTypes = inspection.damageTypes.where(
      (t) => !coveredTypes.contains(t),
    );
    final extraParts = inspection.affectedParts.where(
      (p) => !coveredParts.contains(p),
    );
    if (extraTypes.isNotEmpty || extraParts.isNotEmpty) {
      // An inventory, not an invented per-part diagnosis for older records.
      final row = ReportFinding(
        part: extraParts.isEmpty
            ? 'Diğer Bulgular'
            : extraParts.map((p) => InspectionLabels.label(p) ?? p).join(', '),
      );
      row.damageTypes.addAll(
        extraTypes.map((t) => InspectionLabels.label(t) ?? t),
      );
      groups['unassigned'] = row;
    }
    return groups.values.toList();
  }

  /// Retain unique narrative sentences, including historical safety notes.
  /// Only exact normalized duplicates are removed; no semantic summarization.
  List<String> get narrative {
    final report = inspection.report;
    if (report == null) return const [];
    final primary = [
      inspection.analysisMessage,
      inspection.additionalPhotoGuidance,
      disclaimer,
      for (final finding in findings) ...[
        ...finding.observations,
        ...finding.repairs,
      ],
    ];
    final seen = <String>{
      for (final text in primary) ..._sentences(text).map(_normalize),
    };
    return [
      for (final text in [
        report.summary,
        report.damageDescription,
        report.repairRecommendation,
      ])
        for (final sentence in _sentences(text))
          if (seen.add(_normalize(sentence))) sentence,
    ];
  }

  static List<String> uniqueText(Iterable<String?> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (value != null &&
            value.trim().isNotEmpty &&
            seen.add(_normalize(value)))
          value.trim(),
    ];
  }

  static Iterable<String> _sentences(String? value) => (value ?? '')
      .trim()
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((s) => s.isNotEmpty);
  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  static String money(double value) => value
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
}

class ReportFinding {
  ReportFinding({required this.part});

  final String part;
  final Set<String> damageTypes = {};
  final Set<String> observations = {};
  final Set<String> repairs = {};
}
