import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/app_background.dart';
import 'package:mobile/features/inspection/models/damage_inspection.dart';
import 'package:mobile/features/inspection/screens/inspection_result_screen.dart';
import 'package:mobile/features/inspection/services/inspection_service.dart';

import '../../../support/inspection_report_fixture.dart';
import '../../../support/ui_test_app.dart';

class _SavedInspectionService extends InspectionService {
  _SavedInspectionService(this.current);
  DamageInspection current;
  int reads = 0;

  @override
  Future<DamageInspection> getInspectionById(int id) async {
    reads++;
    return current;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('unified report and details at 320px, $brightness, $scale', (
        tester,
      ) async {
        await setUiSize(tester, const Size(320, 700));
        final service = _SavedInspectionService(reportFixture());
        await tester.pumpWidget(
          uiTestApp(
            brightness: brightness,
            textScale: scale,
            reduceMotion: true,
            home: InspectionResultScreen(
              inspection: service.current,
              inspectionService: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hasar Analiz Raporu'), findsOneWidget);
        expect(find.text('2.500 – 5.000 TRY'), findsOneWidget);
        expect(find.text('Hasar Seviyesi Belirsiz'), findsOneWidget);
        expect(find.textContaining('Güven Skoru'), findsNothing);
        expect(find.text('AI İnceleme Raporu'), findsNothing);

        await tester.scrollUntilVisible(find.text('Bulgular ve Onarım'), 200);
        expect(find.text('Ön kapı'), findsOneWidget);
        expect(find.text('Çizik'), findsOneWidget);
        expect(find.text('Kapıda çizik görünümü var.'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Rapor Ayrıntıları'),
          200,
          maxScrolls: 40,
        );
        expect(find.text('Gizli hasar dışlanamaz.'), findsNothing);
        await tester.tap(find.text('Rapor Ayrıntıları'));
        await tester.pumpAndSettle();
        expect(find.text('Gizli hasar dışlanamaz.'), findsOneWidget);
        expect(find.text('Canlı servis teklifi değildir.'), findsOneWidget);
        expect(find.text('Kapıda çizik görünümü var.'), findsOneWidget);
        expect(
          service.reads,
          0,
          reason: 'Reading a saved report starts no new work',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final outcome in ['NEEDS_MORE_PHOTOS', 'INCONCLUSIVE']) {
    testWidgets('$outcome keeps photo guidance and has no report retry', (
      tester,
    ) async {
      final inspection = reportFixture({
        'status': 'FAILED',
        'reportStatus': 'FAILED',
        'report': null,
        'analysisOutcome': outcome,
        'additionalPhotoGuidance':
            'Hasarın genel görünümünü gün ışığında yeniden çekin.',
      });
      await tester.pumpWidget(
        uiTestApp(home: InspectionResultScreen(inspection: inspection)),
      );
      await tester.pumpAndSettle();
      expect(find.text(inspection.additionalPhotoGuidance!), findsOneWidget);
      expect(find.text('Raporu Tekrar Dene'), findsNothing);
      expect(find.text('İşlem Gerekmiyor'), findsNothing);
      expect(find.text('Henüz belirlenmedi'), findsOneWidget);
      expect(find.byTooltip('PDF Paylaş'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('history follows an ongoing analysis using reads only', (
    tester,
  ) async {
    final service = _SavedInspectionService(
      reportFixture({
        'status': 'PROCESSING',
        'reportStatus': 'PENDING',
        'report': null,
        'damageSeverity': null,
        'visualFindings': [],
        'repairRecommendations': [],
        'damageTypes': [],
        'affectedParts': [],
        'analysisMessage': null,
      }),
    );
    await tester.pumpWidget(
      uiTestApp(
        home: InspectionResultScreen(
          inspection: service.current,
          inspectionService: service,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Analiz Devam Ediyor'), findsOneWidget);
    expect(find.text('Fotoğraflar Değerlendiriliyor'), findsOneWidget);
    expect(find.text('Rapor Hazırlanıyor'), findsNothing);
    expect(find.text('Raporu Tekrar Dene'), findsNothing);
    service.current = reportFixture();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('2.500 – 5.000 TRY'), findsOneWidget);
    expect(service.reads, 1);
    await tester.pumpWidget(const SizedBox());
  });

  if (const bool.fromEnvironment('WRITE_REPORT_PREVIEWS')) {
    for (final brightness in Brightness.values) {
      testWidgets('write report preview $brightness', (tester) async {
        await setUiSize(tester, const Size(390, 844));
        await tester.pumpWidget(
          uiTestApp(
            brightness: brightness,
            reduceMotion: true,
            home: RepaintBoundary(
              key: const Key('preview'),
              child: AppBackground(
                child: InspectionResultScreen(inspection: reportFixture()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('preview')),
        );
        await tester.runAsync(() async {
          final frame = await boundary.toImage(pixelRatio: 2);
          final data = await frame.toByteData(format: ui.ImageByteFormat.png);
          frame.dispose();
          final directory = Directory('build/report-previews')
            ..createSync(recursive: true);
          File(
            '${directory.path}/report-${brightness.name}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        });
      });
    }
  }
}
