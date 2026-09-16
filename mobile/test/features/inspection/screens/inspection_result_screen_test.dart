import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inspection/models/damage_inspection.dart';
import 'package:mobile/features/inspection/models/damage_repair_recommendation.dart';
import 'package:mobile/features/inspection/models/inspection_report.dart';
import 'package:mobile/features/inspection/screens/inspection_result_screen.dart';

void main() {
  testWidgets('no visible damage renders a completed success explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: InspectionResultScreen(inspection: noDamageResult())),
    );

    expect(find.text('Görünür Hasar Tespit Edilmedi'), findsWidgets);
    expect(find.text('İşlem Gerekmiyor'), findsOneWidget);
    expect(
      find.textContaining('mekanik veya profesyonel ekspertiz garantisi değildir'),
      findsOneWidget,
    );
    expect(find.text('Tespit Edilen Hasarlar'), findsNothing);
    expect(find.text('Onarım Önerileri'), findsNothing);
    expect(find.text('Yakındaki Uygun Servisler'), findsNothing);
  });

  testWidgets('minor damage remains a normal detected damage result', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: InspectionResultScreen(inspection: minorResult())),
    );

    expect(find.text('Hafif Seviye Hasar'), findsOneWidget);
    expect(find.text('Tespit Edilen Hasarlar'), findsOneWidget);
    expect(find.text('Çizik'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Onarım Önerileri'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Onarım Önerileri'), findsOneWidget);
    expect(find.text('İşlem Gerekmiyor'), findsNothing);
  });
}

DamageInspection noDamageResult() => DamageInspection(
  id: 1,
  vehicleId: 2,
  vehiclePlate: '35 TEST 01',
  userId: 3,
  imagePath: 'image.jpg',
  status: 'COMPLETED',
  reportStatus: 'COMPLETED',
  reportMessage: null,
  damageSeverity: 'NONE',
  damageTypes: const ['NO_VISIBLE_DAMAGE'],
  affectedParts: const [],
  repairRecommendations: const [
    DamageRepairRecommendation(
      damageType: 'NO_VISIBLE_DAMAGE',
      recommendedAction: 'NO_ACTION',
      partReplacementRequired: false,
      affectedParts: [],
    ),
  ],
  confidenceScore: 0,
  analysisMessage: 'Görünür hasar tespit edilmedi.',
  createdAt: DateTime(2026, 9, 16),
  completedAt: DateTime(2026, 9, 16),
  detections: const [],
  report: InspectionReport(
    title: 'Görünür Hasar Tespit Edilmedi',
    summary: 'Görünür hasar bulunmadı.',
    damageDescription: 'Fotoğrafta görünür hasar bulunmadı.',
    repairRecommendation: 'İşlem önerilmiyor.',
    estimatedMinimumPrice: 0,
    estimatedMaximumPrice: 0,
    currency: 'TRY',
    priceInformation: 'Maliyet hesaplanmadı.',
    priceSourceDescription: 'Görüntü analizi.',
    disclaimer: 'Profesyonel ekspertiz garantisi değildir.',
    generatedAt: null,
  ),
  locationCity: 'İzmir',
  locationLatitude: 38.4,
  locationLongitude: 27.1,
);

DamageInspection minorResult() => DamageInspection(
  id: 4,
  vehicleId: 5,
  vehiclePlate: '35 TEST 02',
  userId: 6,
  imagePath: 'image.jpg',
  status: 'COMPLETED',
  reportStatus: 'PENDING',
  reportMessage: null,
  damageSeverity: 'MINOR',
  damageTypes: const ['SCRATCH'],
  affectedParts: const ['FRONT_BUMPER'],
  repairRecommendations: const [
    DamageRepairRecommendation(
      damageType: 'SCRATCH',
      recommendedAction: 'PAINT_TOUCH_UP',
      partReplacementRequired: false,
      affectedParts: ['FRONT_BUMPER'],
    ),
  ],
  confidenceScore: 0.28,
  analysisMessage: 'Hafif çizik bulundu.',
  createdAt: DateTime(2026, 9, 16),
  completedAt: DateTime(2026, 9, 16),
  detections: const [],
  report: null,
  locationCity: 'İzmir',
  locationLatitude: 38.4,
  locationLongitude: 27.1,
);
