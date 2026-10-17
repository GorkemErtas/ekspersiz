import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/auth/session_manager.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/inspection/models/damage_inspection.dart';
import 'package:mobile/features/inspection/models/damage_repair_recommendation.dart';
import 'package:mobile/features/inspection/models/inspection_report.dart';
import 'package:mobile/features/inspection/screens/inspection_result_screen.dart';
import 'package:mobile/features/inspection/services/inspection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SessionManager.invalidateImages(allowImages: true));

  testWidgets('no visible damage renders a completed success explanation', (
    tester,
  ) async {
    await _pumpResultScreen(tester, noDamageResult());

    expect(find.text('Görünür Hasar Tespit Edilmedi'), findsWidgets);
    expect(find.text('Analiz Fotoğrafı'), findsOneWidget);
    expect(find.byKey(const Key('inspection-analysis-image')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('İşlem Gerekmiyor'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('İşlem Gerekmiyor'), findsOneWidget);
    expect(
      find.textContaining(
        'mekanik veya profesyonel ekspertiz garantisi değildir',
      ),
      findsOneWidget,
    );
    expect(find.text('Tespit Edilen Hasarlar'), findsNothing);
    expect(find.text('Onarım Önerileri'), findsNothing);
    expect(find.text('Yakındaki Uygun Servisler'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Tutanak Oluştur / Görüntüle'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tutanak Oluştur / Görüntüle'), findsOneWidget);
  });

  testWidgets('minor damage remains a normal detected damage result', (
    tester,
  ) async {
    await _pumpResultScreen(tester, minorResult());

    expect(find.text('Hafif Seviye Hasar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tespit Edilen Hasarlar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
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

  testWidgets(
    'session changes remove the visible photo and decoded cache key',
    (tester) async {
      await _pumpResultScreen(tester, noDamageResult());
      final image = tester.widget<Image>(
        find.byKey(const Key('inspection-analysis-image')),
      );
      final key = await image.image.obtainKey(ImageConfiguration.empty);
      SessionManager.invalidateImages(allowImages: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inspection-analysis-image')), findsNothing);
      expect(PaintingBinding.instance.imageCache.containsKey(key), isFalse);
      expect(find.text('Tekrar Dene'), findsOneWidget);
    },
  );

  testWidgets(
    'memory pressure releases the visible encoded and decoded photo',
    (tester) async {
      final service = await _pumpResultScreen(tester, noDamageResult());
      final api = service.apiClient as _ImageApiClient;
      final image = tester.widget<Image>(
        find.byKey(const Key('inspection-analysis-image')),
      );
      final key = await image.image.obtainKey(ImageConfiguration.empty);
      service.images.didHaveMemoryPressure();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inspection-analysis-image')), findsNothing);
      expect(service.images.entryCount, 0);
      expect(PaintingBinding.instance.imageCache.containsKey(key), isFalse);
      expect(
        find.byKey(const Key('inspection-image-placeholder')),
        findsOneWidget,
      );
      expect(find.text('Analiz fotoğrafı yüklenemedi.'), findsNothing);
      expect(
        api.downloads,
        1,
        reason: 'Do not reload immediately under memory pressure',
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('Fotoğrafı Yeniden Yükle'));
        await tester.pump();
        await service.getInspectionImage(1);
      });
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('inspection-analysis-image')),
        findsOneWidget,
      );
      expect(api.downloads, 2);
      expect(api.authorizations, 5); // Initial 2 + cache hit + reloading 2.
    },
  );

  testWidgets('background cleanup shows a placeholder and resume reauthorizes', (
    tester,
  ) async {
    final service = await _pumpResultScreen(tester, noDamageResult());
    final api = service.apiClient as _ImageApiClient;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // Frames resume at inactive, before resumed triggers the automatic reload.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inspection-analysis-image')), findsNothing);
    expect(
      find.byKey(const Key('inspection-image-placeholder')),
      findsOneWidget,
    );
    expect(find.text('Analiz fotoğrafı yüklenemedi.'), findsNothing);
    expect(api.downloads, 1);
    expect(service.images.entryCount, 0);

    await tester.runAsync(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await service.getInspectionImage(1);
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inspection-analysis-image')), findsOneWidget);
    expect(api.downloads, 2);
    expect(api.authorizations, 5);
  });

  testWidgets(
    'a real reload failure after cleanup still shows the retry error',
    (tester) async {
      final service = await _pumpResultScreen(tester, noDamageResult());
      final api = service.apiClient as _ImageApiClient;
      service.images.didHaveMemoryPressure();
      await tester.pumpAndSettle();
      api.error = const ApiException(statusCode: 403, message: 'Denied');
      await tester.tap(find.text('Fotoğrafı Yeniden Yükle'));
      await tester.pumpAndSettle();
      expect(find.text('Analiz fotoğrafı yüklenemedi.'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.byKey(const Key('inspection-analysis-image')), findsNothing);
      expect(service.images.entryCount, 0);
      expect(api.downloads, 1);
    },
  );

  testWidgets(
    'local invalidation leaves other open photos intact, global cleanup clears both',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = await rootBundle.load('assets/images/ekspersiz_logo.png');
      final api = _ImageApiClient(data.buffer.asUint8List());
      final service = InspectionService(apiClient: api);
      await tester.runAsync(() async {
        await service.getInspectionImage(1);
        await service.getInspectionImage(4);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              Expanded(
                child: InspectionResultScreen(
                  key: const Key('result-1'),
                  inspection: noDamageResult(),
                  inspectionService: service,
                ),
              ),
              Expanded(
                child: InspectionResultScreen(
                  key: const Key('result-4'),
                  inspection: minorResult(),
                  inspectionService: service,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final otherPhoto = find.descendant(
        of: find.byKey(const Key('result-4')),
        matching: find.byKey(const Key('inspection-analysis-image')),
      );
      final unaffected = tester.widget<Image>(otherPhoto);
      expect(
        find.byKey(const Key('inspection-analysis-image')),
        findsNWidgets(2),
      );
      service.images.invalidate(1);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('inspection-analysis-image')),
        findsOneWidget,
      );
      expect(tester.widget<Image>(otherPhoto), same(unaffected));
      expect(api.downloads, 2);
      expect(service.images.entryCount, 1);

      SessionManager.invalidateImages(allowImages: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inspection-analysis-image')), findsNothing);
      expect(service.images.entryCount, 0);
    },
  );

  testWidgets('preview decode is bounded and preserves aspect ratio', (
    tester,
  ) async {
    await _pumpResultScreen(tester, noDamageResult());
    final image = tester.widget<Image>(
      find.byKey(const Key('inspection-analysis-image')),
    );
    final provider = image.image as ResizeImage;
    expect(provider.width, lessThanOrEqualTo(1600));
    expect(provider.height, lessThanOrEqualTo(1000));
    expect(provider.policy, ResizeImagePolicy.fit);
    expect(provider.allowUpscaling, isFalse);
    expect(image.fit, BoxFit.contain);
  });
}

Future<InspectionService> _pumpResultScreen(
  WidgetTester tester,
  DamageInspection inspection,
) async {
  final imageData = await rootBundle.load('assets/images/ekspersiz_logo.png');
  final imageBytes = imageData.buffer.asUint8List(
    imageData.offsetInBytes,
    imageData.lengthInBytes,
  );
  final service = InspectionService(apiClient: _ImageApiClient(imageBytes));
  // The engine codec uses real async work, outside the widget fake clock.
  await tester.runAsync(() => service.getInspectionImage(inspection.id));

  await tester.pumpWidget(
    MaterialApp(
      home: InspectionResultScreen(
        inspection: inspection,
        inspectionService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

class _ImageApiClient extends ApiClient {
  _ImageApiClient(this.imageBytes);

  final Uint8List imageBytes;
  int downloads = 0;
  int authorizations = 0;
  ApiException? error;

  @override
  Future<dynamic> get(String path) async {
    authorizations++;
    if (error != null) throw error!;
    return {'id': int.parse(path.split('/').last), 'imagePath': 'image.jpg'};
  }

  @override
  Future<Uint8List> getBytes(String path) async {
    downloads++;
    return imageBytes;
  }
}

DamageInspection noDamageResult() => DamageInspection(
  id: 1,
  vehicleId: 2,
  vehiclePlate: '35 TEST 01',
  vehicleBrand: 'Test',
  vehicleModel: 'Araç',
  vehicleModelYear: 2024,
  vehicleMileage: 12000,
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
  vehicleBrand: 'Test',
  vehicleModel: 'Araç',
  vehicleModelYear: 2024,
  vehicleMileage: 13000,
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
