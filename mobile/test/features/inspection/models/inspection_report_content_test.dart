import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inspection/models/inspection_report_content.dart';

import '../../../support/inspection_report_fixture.dart';

void main() {
  test('merges part, type and repair without duplicating visual evidence', () {
    final inspection = reportFixture();
    final content = InspectionReportContent(inspection);
    final row = content.findings.single;
    expect(row.part, 'Ön kapı');
    expect(row.damageTypes, ['Çizik']);
    expect(row.observations, ['Kapıda çizik görünümü var.']);
    expect(row.repairs, contains('Boya derinliği serviste kontrol edilmeli.'));
    expect(row.repairs, contains('Lokal Boya Rötuşu'));
    expect(content.title, 'Hasar Seviyesi Belirsiz');
    expect(content.price, '2.500 – 5.000 TRY');
    expect(content.narrative, ['Gizli hasar dışlanamaz.']);
    expect(content.disclaimer, contains('Sürüş güvenliği'));
    // Stored fields and uncalibrated confidence remain untouched.
    expect(inspection.report!.summary, 'Kapıda çizik görünümü var.');
    expect(inspection.confidenceScore, isNull);
  });

  test(
    'keeps different observations on the same part and replacement uncertainty',
    () {
      final content = InspectionReportContent(
        reportFixture({
          'visualFindings': [
            {
              'damageType': 'SCRATCH',
              'affectedPart': 'FRONT_DOOR',
              'severity': 'MINOR',
              'description': 'Yüzeyde çizik var.',
              'repairNotes': 'Boya kontrolü önerilir.',
              'replacementAssessment': 'POSSIBLE',
            },
            {
              'damageType': 'DENT',
              'affectedPart': 'FRONT_DOOR',
              'severity': 'UNKNOWN',
              'description': 'Alt kenarda göçük olabilir.',
              'repairNotes': 'Derinlik belirsiz.',
              'replacementAssessment': 'UNDETERMINED',
            },
          ],
        }),
      );
      expect(content.findings, hasLength(1));
      final row = content.findings.single;
      expect(row.damageTypes, containsAll(['Çizik', 'Göçük']));
      expect(
        row.observations,
        containsAll(['Alt kenarda göçük olabilir.', 'Hafif Seviye Hasar']),
      );
      expect(
        row.repairs,
        contains('Parça değişimi gerekebilir; fiziksel incelemeyle netleşir.'),
      );
    },
  );

  for (final outcome in ['NEEDS_MORE_PHOTOS', 'INCONCLUSIVE']) {
    test('$outcome cannot become a no-damage success or a free repair', () {
      final content = InspectionReportContent(
        reportFixture({
          'status': 'FAILED',
          'analysisOutcome': outcome,
          'damageSeverity': 'UNKNOWN',
          'report': null,
          'additionalPhotoGuidance': 'Aynı bölgeyi gün ışığında yeniden çekin.',
        }),
      );
      expect(content.noVisibleDamage, isFalse);
      expect(
        content.title,
        outcome == 'INCONCLUSIVE' ? 'Sonuç Belirsiz' : 'Ek Fotoğraf Gerekli',
      );
      expect(content.price, 'Henüz belirlenmedi');
      expect(content.inspection.additionalPhotoGuidance, isNotEmpty);
    });
  }

  test('legacy inventory does not invent a relationship between arrays', () {
    final content = InspectionReportContent(
      reportFixture({
        'schemaVersion': null,
        'visualFindings': [],
        'repairRecommendations': [],
        'damageTypes': ['DENT', 'CRACKED'],
        'affectedParts': ['FRONT_BUMPER', 'HOOD'],
      }),
    );
    expect(content.findings, hasLength(1));
    expect(content.findings.single.part, 'Ön tampon, Kaput');
    expect(content.findings.single.damageTypes, ['Göçük', 'Çatlak']);
    expect(content.findings.single.repairs, isEmpty);
  });

  test(
    'generic inspection fallback does not repeat substantive repair notes',
    () {
      final row = InspectionReportContent(
        reportFixture({
          'repairRecommendations': [
            {
              'damageType': 'SCRATCH',
              'affectedParts': ['FRONT_DOOR'],
              'recommendedAction': 'PROFESSIONAL_INSPECTION',
              'partReplacementRequired': null,
            },
          ],
        }),
      ).findings.single;
      expect(row.repairs, [
        'Boya derinliği serviste kontrol edilmeli.',
        'Parça değişimi gereksinimi fiziksel incelemeyle belirlenecek.',
      ]);
    },
  );

  test('zero or invalid cost is unavailable, never a free repair claim', () {
    for (final prices in [
      [0, 0],
      [5000, 2000],
      [-1, 1000],
    ]) {
      final content = InspectionReportContent(
        reportFixture({
          'report': {
            'estimatedMinimumPrice': prices[0],
            'estimatedMaximumPrice': prices[1],
          },
        }),
      );
      expect(content.hasPrice, isFalse);
      expect(content.price, 'Henüz belirlenmedi');
    }
  });
}
