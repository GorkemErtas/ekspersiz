import type { Inspection } from '../../core/models';
import { inspectionOnly, needsMorePhotos } from '../../core/models';
import { label } from '../../core/labels';
const normalize = (text: string) =>
  text.trim().replace(/\s+/g, ' ').toLocaleLowerCase('tr-TR');
export function uniqueText(values: (string | null | undefined)[]) {
  const seen = new Set<string>();
  return values
    .filter(
      (value): value is string =>
        !!value?.trim() &&
        !seen.has(normalize(value)) &&
        !!seen.add(normalize(value)),
    )
    .map((value) => value.trim());
}
const sentences = (value: string | null | undefined) =>
  (value ?? '')
    .trim()
    .replace(/([.!?])\s+/g, '$1\u0000')
    .split('\u0000')
    .filter(Boolean);
export interface ReportFinding {
  part: string;
  damageTypes: string[];
  observations: string[];
  repairs: string[];
}
export function reportContent(inspection: Inspection) {
  const noDamage =
      inspection.status === 'COMPLETED' &&
      !needsMorePhotos(inspection) &&
      inspection.damageSeverity === 'NONE',
    groups = new Map<string, ReportFinding>(),
    coveredTypes = new Set<string>(),
    coveredParts = new Set<string>();
  const group = (key: string, title = label(key)) => {
    let value = groups.get(key);
    if (!value) {
      value = { part: title, damageTypes: [], observations: [], repairs: [] };
      groups.set(key, value);
    }
    return value;
  };
  if (!noDamage) {
    for (const finding of inspection.visualFindings ?? []) {
      const row = group(finding.affectedPart);
      row.damageTypes.push(label(finding.damageType));
      row.observations.push(
        finding.description?.trim() || label(finding.severity),
      );
      row.repairs.push(
        ...uniqueText([finding.repairNotes]),
        finding.replacementAssessment === 'POSSIBLE'
          ? 'Parça değişimi gerekebilir; fiziksel incelemeyle netleşir.'
          : finding.replacementAssessment === 'NOT_INDICATED'
            ? 'Fotoğraflarda parça değişimi gereksinimi görülmedi; fiziksel inceleme gerekir.'
            : 'Parça değişimi gereksinimi fiziksel incelemeyle belirlenecek.',
      );
      coveredTypes.add(finding.damageType);
      coveredParts.add(finding.affectedPart);
    }
    for (const recommendation of inspection.repairRecommendations ?? []) {
      const parts = recommendation.affectedParts ?? [],
        row = group(
          parts.join(', '),
          parts.length
            ? parts.map(label).join(', ')
            : 'Konumu Belirlenemeyen Bulgu',
        );
      row.damageTypes.push(label(recommendation.damageType));
      const visual = inspection.visualFindings?.some(
        (item) =>
          parts.includes(item.affectedPart) &&
          item.damageType === recommendation.damageType &&
          item.repairNotes?.trim(),
      );
      if (
        recommendation.recommendedAction !== 'PROFESSIONAL_INSPECTION' ||
        !visual
      )
        row.repairs.push(label(recommendation.recommendedAction));
      if (recommendation.partReplacementRequired === true)
        row.repairs.push(
          'Analizde parça değişimi önerildi; fiziksel incelemeyle doğrulanmalıdır.',
        );
      else if (recommendation.partReplacementRequired == null && !visual)
        row.repairs.push(
          'Parça değişimi gereksinimi fiziksel incelemeyle belirlenecek.',
        );
      coveredTypes.add(recommendation.damageType);
      parts.forEach((part) => coveredParts.add(part));
    }
    const extraParts = (inspection.affectedParts ?? []).filter(
        (part) => !coveredParts.has(part),
      ),
      extraTypes = (inspection.damageTypes ?? []).filter(
        (type) => !coveredTypes.has(type),
      );
    if (extraParts.length || extraTypes.length)
      group(
        'unassigned',
        extraParts.length ? extraParts.map(label).join(', ') : 'Diğer Bulgular',
      ).damageTypes.push(...extraTypes.map(label));
  }
  const findings = [...groups.values()].map((row) => ({
    ...row,
    damageTypes: uniqueText(row.damageTypes),
    observations: uniqueText(row.observations),
    repairs: uniqueText(row.repairs),
  }));
  const report = inspection.report,
    disclaimer =
      report?.disclaimer?.trim() ||
      'Bu değerlendirme yalnızca fotoğraflarda görünen alanlarla sınırlıdır; mekanik veya profesyonel ekspertiz garantisi değildir. Kesin işlem ve maliyet fiziksel incelemeyle belirlenir.';
  const seen = new Set(
    [
      inspection.analysisMessage,
      inspection.additionalPhotoGuidance,
      disclaimer,
      ...findings.flatMap((row) => [...row.observations, ...row.repairs]),
    ]
      .flatMap(sentences)
      .map(normalize),
  );
  const narrative = [
    report?.summary,
    report?.damageDescription,
    report?.repairRecommendation,
  ]
    .flatMap(sentences)
    .filter(
      (sentence) =>
        !seen.has(normalize(sentence)) && !!seen.add(normalize(sentence)),
    );
  const hasPrice =
    !!report &&
    Number.isFinite(report.estimatedMinimumPrice) &&
    Number.isFinite(report.estimatedMaximumPrice) &&
    report.estimatedMinimumPrice >= 0 &&
    report.estimatedMaximumPrice > 0 &&
    report.estimatedMaximumPrice >= report.estimatedMinimumPrice;
  return {
    noDamage,
    findings,
    narrative,
    disclaimer,
    title: needsMorePhotos(inspection)
      ? inspection.analysisOutcome === 'INCONCLUSIVE'
        ? 'Sonuç Belirsiz'
        : 'Ek Fotoğraf Gerekli'
      : inspection.status === 'COMPLETED'
        ? ({
            NONE: 'Görünür Hasar Tespit Edilmedi',
            MINOR: 'Hafif Seviye Hasar',
            MODERATE: 'Orta Seviye Hasar',
            SEVERE: 'Ağır Seviye Hasar',
          }[inspection.damageSeverity ?? ''] ?? 'Hasar Seviyesi Belirsiz')
        : label(inspection.status),
    priceTitle: inspectionOnly(inspection)
      ? 'Tahmini Fiziksel İnceleme Maliyeti'
      : 'Tahmini Onarım Maliyeti',
    price: hasPrice
      ? `${Math.round(report!.estimatedMinimumPrice).toLocaleString('tr-TR')} – ${Math.round(report!.estimatedMaximumPrice).toLocaleString('tr-TR')} ${report!.currency}`
      : noDamage
        ? 'Maliyet hesaplanmadı'
        : 'Henüz belirlenmedi',
  };
}
