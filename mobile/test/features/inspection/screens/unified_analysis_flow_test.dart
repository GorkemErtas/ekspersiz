import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/inspection/models/damage_inspection.dart';
import 'package:mobile/features/inspection/screens/analyzing_screen.dart';
import 'package:mobile/features/inspection/screens/inspection_result_screen.dart';
import 'package:mobile/features/inspection/services/inspection_service.dart';

import '../../../support/ui_test_app.dart';

DamageInspection _inspection({
  String status = 'COMPLETED',
  String report = 'PROCESSING',
}) => DamageInspection.fromJson({
  'id': 4,
  'vehicleId': 1,
  'vehiclePlate': '34 ABC 123',
  'vehicleBrand': 'Honda',
  'vehicleModel': 'Civic',
  'vehicleModelYear': 2024,
  'vehicleMileage': 50000,
  'userId': 1,
  'status': status,
  'reportStatus': report,
  'damageSeverity': 'MINOR',
  'damageTypes': ['SCRATCH'],
  'affectedParts': ['FRONT_BUMPER'],
  'confidenceScore': 0.9,
  'locationCity': 'İstanbul',
  'repairRecommendations': [
    {
      'damageType': 'SCRATCH',
      'recommendedAction': 'PAINT_TOUCH_UP',
      'partReplacementRequired': false,
      'affectedParts': ['FRONT_BUMPER'],
    },
  ],
  if (report == 'COMPLETED')
    'report': {
      'title': 'Hasar değerlendirmesi',
      'summary': 'Ön tamponda yüzeysel çizik tespit edildi.',
      'damageDescription': 'Görselde yüzeysel çizikler bulunuyor.',
      'repairRecommendation': 'Lokal boya rötuşu önerilir.',
      'estimatedMinimumPrice': 1000,
      'estimatedMaximumPrice': 2000,
      'currency': 'TRY',
      'priceInformation': 'Bölgesel işçilik tahmini.',
      'priceSourceDescription': 'Genel piyasa tahmini.',
      'disclaimer': 'Kesin servis teklifi değildir.',
    },
});

class _FlowService extends InspectionService {
  _FlowService(this.current);
  DamageInspection current;
  Future<DamageInspection> Function()? analyze;
  Future<DamageInspection> Function()? report;
  Object? readError;
  int analyses = 0;
  int reports = 0;
  int reads = 0;

  @override
  Future<DamageInspection> analyzeInspection(
    int inspectionId, {
    required String vehicleRegion,
  }) async {
    analyses++;
    expect(inspectionId, 4);
    expect(vehicleRegion, 'FRONT');
    return analyze == null ? current : await analyze!();
  }

  @override
  Future<DamageInspection> getInspectionById(int inspectionId) async {
    reads++;
    if (readError != null) throw readError!;
    return current;
  }

  @override
  Future<DamageInspection> regenerateReport(int inspectionId) async {
    reports++;
    return report == null ? current : await report!();
  }
}

Future<void> _pumpAnalysis(
  WidgetTester tester,
  _FlowService service, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    uiTestApp(
      brightness: brightness,
      textScale: scale,
      reduceMotion: true,
      home: AnalyzingScreen(
        inspection: _inspection(status: 'PENDING', report: 'PENDING'),
        vehicleRegion: 'FRONT',
        inspectionService: service,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _showReportRetry(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('AI Raporunu Tekrar Dene'),
    200,
    maxScrolls: 40,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('AI Raporunu Tekrar Dene'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);

  testWidgets(
    '422 shows the rejected photo and reason without retrying paid work',
    (tester) async {
      const message =
          'Genel görünüm fotoğrafı: Fotoğraf 24 MP sınırını aşıyor.';
      final service =
          _FlowService(_inspection(status: 'PENDING', report: 'PENDING'))
            ..analyze = () async =>
                throw const ApiException(statusCode: 422, message: message);
      await _pumpAnalysis(tester, service);
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(service.analyses, 1);
      expect(service.reports, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'one screen shows real ML/report stages then combined results: $brightness',
      (tester) async {
        await setUiSize(tester, const Size(320, 640));
        final response = Completer<DamageInspection>();
        final service = _FlowService(_inspection(status: 'PROCESSING'))
          ..analyze = () => response.future;
        await _pumpAnalysis(tester, service, brightness: brightness, scale: 2);
        expect(find.text('Aracınız analiz ediliyor'), findsOneWidget);
        service.current = _inspection();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(find.text('AI raporunuz hazırlanıyor'), findsOneWidget);
        expect(find.byType(InspectionResultScreen), findsNothing);
        expect(find.text('Detaylı AI Raporu Oluştur'), findsNothing);
        service.current = _inspection(report: 'COMPLETED');
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byType(InspectionResultScreen), findsOneWidget);
        final screen = tester.widget<InspectionResultScreen>(
          find.byType(InspectionResultScreen),
        );
        expect(screen.inspection.damageTypes, ['SCRATCH']);
        expect(screen.inspection.damageSeverity, 'MINOR');
        expect(screen.inspection.affectedParts, ['FRONT_BUMPER']);
        expect(screen.inspection.repairRecommendations, hasLength(1));
        await tester.scrollUntilVisible(
          find.text('Tahmini Onarım Maliyeti'),
          200,
          maxScrolls: 40,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Tahmini Onarım Maliyeti'), findsOneWidget);
        expect(screen.inspection.report!.estimatedMinimumPrice, 1000);
        response.complete(service.current);
        await tester.pumpAndSettle();
        expect(service.analyses, 1);
        expect(
          service.reports,
          0,
          reason: 'The backend already generated the report',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'failed report preserves ML and retry only generates a report once',
    (tester) async {
      final service = _FlowService(_inspection(report: 'FAILED'));
      await _pumpAnalysis(tester, service);
      expect(find.byType(InspectionResultScreen), findsOneWidget);
      expect(
        service.reports,
        0,
        reason: 'Do not automatically loop on a report failure',
      );
      final response = Completer<DamageInspection>();
      service.report = () => response.future;
      await _showReportRetry(tester);
      await tester.tap(find.text('AI Raporunu Tekrar Dene'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('AI Raporunu Tekrar Dene'));
      await tester.pump();
      expect(service.reports, 1);
      service.current = _inspection(report: 'COMPLETED');
      response.complete(service.current);
      await tester.pumpAndSettle();
      expect(find.text('AI İnceleme Raporu'), findsOneWidget);
      expect(find.text('AI Raporunu Tekrar Dene'), findsNothing);
      expect(service.analyses, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'lost analyze response waits for existing report without another POST',
    (tester) async {
      final service = _FlowService(_inspection())
        ..analyze = () async =>
            throw const ApiException(statusCode: 408, message: 'Timeout');
      await _pumpAnalysis(tester, service);
      expect(find.text('AI raporunuz hazırlanıyor'), findsOneWidget);
      service.current = _inspection(report: 'COMPLETED');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(InspectionResultScreen), findsOneWidget);
      expect(service.analyses, 1);
      expect(service.reports, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('offline retry first reads saved result and never repeats ML', (
    tester,
  ) async {
    final service = _FlowService(_inspection())
      ..readError = const ApiException(statusCode: 0, message: 'Offline')
      ..analyze = () async =>
          throw const ApiException(statusCode: 0, message: 'Offline');
    await _pumpAnalysis(tester, service);
    expect(find.text('Sonucu Kontrol Et'), findsOneWidget);
    service.readError = null;
    service.current = _inspection(report: 'COMPLETED');
    await tester.tap(find.text('Sonucu Kontrol Et'));
    await tester.pumpAndSettle();
    expect(find.byType(InspectionResultScreen), findsOneWidget);
    expect(service.analyses, 1);
    expect(service.reports, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'old-server pending response automatically generates report only once',
    (tester) async {
      final response = Completer<DamageInspection>();
      final service = _FlowService(_inspection(report: 'PENDING'))
        ..report = () => response.future;
      await _pumpAnalysis(tester, service);
      expect(find.text('AI raporunuz hazırlanıyor'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(service.reports, 1);
      expect(find.byType(InspectionResultScreen), findsNothing);
      service.current = _inspection(report: 'COMPLETED');
      response.complete(service.current);
      await tester.pumpAndSettle();
      expect(find.byType(InspectionResultScreen), findsOneWidget);
      expect(service.analyses, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'legacy report timeout keeps ML instead of requesting another analysis',
    (tester) async {
      final service = _FlowService(_inspection(report: 'PENDING'))
        ..report = () async =>
            throw const ApiException(statusCode: 408, message: 'Timeout');
      await _pumpAnalysis(tester, service);
      expect(find.byType(InspectionResultScreen), findsOneWidget);
      await _showReportRetry(tester);
      expect(service.analyses, 1);
      expect(service.reports, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'history watches a processing report without starting ML or Gemini',
    (tester) async {
      await setUiSize(tester, const Size(800, 2000));
      final service = _FlowService(_inspection(report: 'COMPLETED'));
      await tester.pumpWidget(
        uiTestApp(
          reduceMotion: true,
          home: InspectionResultScreen(
            inspection: _inspection(),
            inspectionService: service,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Detaylı AI raporu hazırlanıyor'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('AI İnceleme Raporu'), findsOneWidget);
      expect(service.analyses, 0);
      expect(service.reports, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'lost report retry response recovers saved report without another POST',
    (tester) async {
      await setUiSize(tester, const Size(800, 2000));
      final service = _FlowService(_inspection(report: 'FAILED'));
      service.report = () async {
        service.current = _inspection(report: 'COMPLETED');
        throw const ApiException(statusCode: 408, message: 'Timeout');
      };
      await tester.pumpWidget(
        uiTestApp(
          reduceMotion: true,
          home: InspectionResultScreen(
            inspection: service.current,
            inspectionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _showReportRetry(tester);
      await tester.tap(find.text('AI Raporunu Tekrar Dene'));
      await tester.pumpAndSettle();
      expect(find.text('AI İnceleme Raporu'), findsOneWidget);
      expect(service.reports, 1);
      expect(service.analyses, 0);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a stalled report offers guarded report-only recovery after bounded polling',
    (tester) async {
      await setUiSize(tester, const Size(800, 2000));
      final service = _FlowService(_inspection());
      await tester.pumpWidget(
        uiTestApp(
          reduceMotion: true,
          home: InspectionResultScreen(
            inspection: service.current,
            inspectionService: service,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('AI Raporunu Tekrar Dene'), findsNothing);
      await tester.pump(const Duration(minutes: 3));
      await tester.pump();
      expect(find.text('AI Raporunu Tekrar Dene'), findsOneWidget);
      expect(service.reports, 0);
      service.report = () async => _inspection(report: 'COMPLETED');
      await tester.ensureVisible(find.text('AI Raporunu Tekrar Dene'));
      await tester.tap(find.text('AI Raporunu Tekrar Dene'));
      await tester.pumpAndSettle();
      expect(service.reports, 1);
      expect(service.analyses, 0);
      expect(find.text('AI İnceleme Raporu'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('long wait permits status check and never silently restarts ML', (
    tester,
  ) async {
    final service = _FlowService(_inspection(status: 'PROCESSING'));
    await _pumpAnalysis(tester, service);
    await tester.pump(const Duration(minutes: 3));
    await tester.pumpAndSettle();
    expect(find.text('Sonucu Kontrol Et'), findsOneWidget);
    service.current = _inspection(report: 'COMPLETED');
    await tester.tap(find.text('Sonucu Kontrol Et'));
    await tester.pumpAndSettle();
    expect(find.byType(InspectionResultScreen), findsOneWidget);
    expect(service.analyses, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'disposing the progress screen stops reads and ignores late completion',
    (tester) async {
      final response = Completer<DamageInspection>();
      final service = _FlowService(_inspection(status: 'PROCESSING'))
        ..analyze = () => response.future;
      await _pumpAnalysis(tester, service);
      await tester.pumpWidget(const SizedBox());
      response.complete(_inspection(report: 'COMPLETED'));
      await tester.pump(const Duration(seconds: 5));
      expect(service.reads, 0);
      expect(find.byType(InspectionResultScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
