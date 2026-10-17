import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/widgets/primary_button.dart';
import 'package:mobile/features/inspection/models/damage_inspection.dart';
import 'package:mobile/features/inspection/screens/analyzing_screen.dart';
import 'package:mobile/features/inspection/screens/inspection_result_screen.dart';
import 'package:mobile/features/inspection/screens/upload_damage_image_screen.dart';
import 'package:mobile/features/inspection/services/inspection_service.dart';

import '../../../support/ui_mock_api.dart';
import '../../../support/ui_test_app.dart';

const _pending = {
  'id': 4,
  'vehicleId': 1,
  'vehiclePlate': '34 ABC 123',
  'vehicleBrand': 'Honda',
  'vehicleModel': 'Civic',
  'vehicleModelYear': 2024,
  'vehicleMileage': 50000,
  'userId': 1,
  'status': 'PENDING',
  'reportStatus': 'PENDING',
  'locationCity': 'İstanbul',
};
final _complete = {
  ..._pending,
  'status': 'COMPLETED',
  'reportStatus': 'COMPLETED',
  'damageSeverity': 'NONE',
  'damageTypes': ['NO_VISIBLE_DAMAGE'],
  'analysisMessage': 'Görünür hasar tespit edilmedi.',
  'report': {
    'title': 'Görünür Hasar Tespit Edilmedi',
    'summary': 'Görünür hasar yok.',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);
  setUp(initializeUiSession);

  for (final region in ['FRONT', 'REAR']) {
    testWidgets(
      'one upload, mandatory $region, camera/gallery and no duplicate submit',
      (tester) async {
        await setUiSize(tester, const Size(320, 640));
        final bytes = await _photoBytes();
        final picker = _MemoryPicker(bytes);
        final uploaded = Completer<http.Response>();
        final requests = <http.Request>[];
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              uiTestApp(
                home: UploadDamageImageScreen(
                  inspection: DamageInspection.fromJson(_pending),
                  imagePicker: picker,
                ),
                textScale: 2,
                reduceMotion: true,
              ),
            );
            await tester.pumpAndSettle();
            await _pickPhoto(tester, camera: region == 'FRONT');
            await _showPrimary(tester);
            expect(
              tester
                  .widget<PrimaryButton>(find.byType(PrimaryButton))
                  .onPressed,
              isNull,
            );
            expect(
              requests,
              isEmpty,
              reason: 'Region is required before any upload',
            );
            await tester.scrollUntilVisible(
              find.text(region == 'FRONT' ? 'Ön yarı' : 'Arka yarı'),
              -150,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(
              find.text(region == 'FRONT' ? 'Ön yarı' : 'Arka yarı'),
            );
            await tester.tap(
              find.text(region == 'FRONT' ? 'Ön yarı' : 'Arka yarı'),
            );
            await _showPrimary(tester);
            await tester.tap(find.byType(PrimaryButton));
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              tester
                  .widget<PrimaryButton>(find.byType(PrimaryButton))
                  .isLoading,
              isTrue,
            );
            await tester.tap(find.byType(PrimaryButton));
            await tester.pump();
            expect(requests.length, 1);
            expect(requests.single.url.path, endsWith('/inspections/4/image'));
            expect(
              latin1.decode(requests.single.bodyBytes),
              contains('name="image"'),
            );
            expect(
              latin1.decode(requests.single.bodyBytes),
              isNot(contains('context_image')),
            );
            uploaded.complete(uiJsonResponse(_pending));
            await tester.pumpAndSettle();
            expect(find.byType(InspectionResultScreen), findsOneWidget);
            expect(picker.sources, [
              region == 'FRONT' ? ImageSource.camera : ImageSource.gallery,
            ]);
            expect(
              requests.map((request) => request.url.path.split('/').last),
              ['image', 'image-quality', 'analyze'],
            );
            expect(requests.last.url.queryParameters, {
              'vehicleRegion': region,
            });
            expect(find.text('Görünür Hasar Tespit Edilmedi'), findsWidgets);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/image')) return uploaded.future;
            if (request.url.path.endsWith('/image-quality')) {
              return uiJsonResponse({
                'suitable': true,
                'code': 'SUITABLE',
                'message': 'Uygun',
              });
            }
            if (request.url.path.endsWith('/analyze')) {
              return uiJsonResponse(_complete);
            }
            throw StateError('Unexpected call: ${request.url}');
          }),
        );
      },
    );
  }

  testWidgets(
    'unsuitable photo keeps the preview and provides a replacement action',
    (tester) async {
      final picker = _MemoryPicker(await _photoBytes());
      var analyses = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            uiTestApp(
              home: UploadDamageImageScreen(
                inspection: DamageInspection.fromJson(_pending),
                imagePicker: picker,
              ),
              reduceMotion: true,
            ),
          );
          await tester.pumpAndSettle();
          await _pickPhoto(tester);
          await _selectFront(tester);
          await tester.tap(find.byType(PrimaryButton));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Fotoğrafı yeniden çekin'),
            -150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.textContaining('Fotoğraf çok bulanık'), findsOneWidget);
          expect(find.byType(AnalyzingScreen), findsNothing);
          expect(analyses, 0);
          await tester.scrollUntilVisible(
            find.text('Değiştir'),
            -150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(find.text('Değiştir'));
          await tester.tap(find.text('Değiştir'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Galeriden seç'));
          await tester.tap(find.text('Galeriden seç'));
          await tester.pumpAndSettle();
          expect(picker.sources.length, 2);
          expect(find.textContaining('Fotoğraf çok bulanık'), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/image')) {
            return uiJsonResponse(_pending);
          }
          if (request.url.path.endsWith('/image-quality')) {
            return uiJsonResponse({
              'suitable': false,
              'code': 'TOO_BLURRY',
              'message': 'Fotoğraf çok bulanık. Kamerayı sabit tutun.',
            });
          }
          analyses++;
          throw StateError('Unsuitable image must not be analyzed');
        }),
      );
    },
  );

  testWidgets('analysis retry reuses the single photo and retains region', (
    tester,
  ) async {
    var uploads = 0;
    final regions = <String?>[];
    final picker = _MemoryPicker(await _photoBytes());
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          uiTestApp(
            home: UploadDamageImageScreen(
              inspection: DamageInspection.fromJson(_pending),
              imagePicker: picker,
            ),
            reduceMotion: true,
          ),
        );
        await tester.pumpAndSettle();
        await _pickPhoto(tester);
        await _selectFront(tester);
        await tester.tap(find.byType(PrimaryButton));
        await tester.pumpAndSettle();
        expect(find.text('Analiz tamamlanamadı'), findsOneWidget);
        await tester.ensureVisible(find.text('Analizi Tekrar Dene'));
        await tester.tap(find.text('Analizi Tekrar Dene'));
        await tester.pumpAndSettle();
        expect(find.byType(InspectionResultScreen), findsOneWidget);
        expect(uploads, 1);
        expect(regions, ['FRONT', 'FRONT']);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/image')) {
          uploads++;
          return uiJsonResponse(_pending);
        }
        if (request.url.path.endsWith('/image-quality')) {
          return uiJsonResponse({
            'suitable': true,
            'code': 'SUITABLE',
            'message': 'Uygun',
          });
        }
        if (request.url.path.endsWith('/analyze')) {
          regions.add(request.url.queryParameters['vehicleRegion']);
          return regions.length == 1
              ? http.Response(
                  jsonEncode({
                    'message': 'Servis geçici olarak kullanılamıyor.',
                  }),
                  503,
                )
              : uiJsonResponse(_complete);
        }
        throw StateError('Unexpected call: ${request.url}');
      }),
    );
  });

  testWidgets('invalid region is rejected locally before any request', (
    tester,
  ) async {
    var requests = 0;
    await http.runWithClient(
      () async {
        await expectLater(
          const InspectionService().analyzeInspection(4, vehicleRegion: 'SIDE'),
          throwsFormatException,
        );
        expect(requests, 0);
      },
      () => MockClient((_) async {
        requests++;
        return uiJsonResponse(_complete);
      }),
    );
  });
}

Future<Uint8List> _photoBytes() async {
  final data = await rootBundle.load('assets/images/ekspersiz_logo.png');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<void> _showPrimary(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(PrimaryButton),
    180,
    maxScrolls: 40,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.byType(PrimaryButton));
  await tester.pumpAndSettle();
}

Future<void> _pickPhoto(WidgetTester tester, {bool camera = false}) async {
  await _showPrimary(tester);
  await tester.tap(find.byType(PrimaryButton));
  await tester.pumpAndSettle();
  final option = find.text(camera ? 'Kamera ile çek' : 'Galeriden seç');
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

Future<void> _selectFront(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Ön yarı'),
    -150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Ön yarı'));
  await tester.tap(find.text('Ön yarı'));
  await _showPrimary(tester);
}

class _MemoryPicker extends ImagePicker {
  _MemoryPicker(this.bytes);
  final Uint8List bytes;
  final sources = <ImageSource>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sources.add(source);
    return XFile.fromData(
      bytes,
      name: 'damage-${sources.length}.png',
      mimeType: 'image/png',
    );
  }
}
