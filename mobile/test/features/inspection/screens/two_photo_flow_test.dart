import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/widgets/primary_button.dart';
import 'package:mobile/features/inspection/models/damage_inspection.dart';
import 'package:mobile/features/inspection/screens/upload_damage_image_screen.dart';
import 'package:mobile/features/inspection/screens/inspection_result_screen.dart';
import 'package:mobile/features/inspection/services/inspection_service.dart';
import '../../../support/ui_test_app.dart';

DamageInspection inspection({bool complete = false}) =>
    DamageInspection.fromJson({
      'id': 4,
      'vehicleId': 1,
      'vehiclePlate': '34 TEST 1',
      'vehicleBrand': 'Test',
      'vehicleModel': 'Car',
      'locationCity': 'İzmir',
      'status': complete ? 'COMPLETED' : 'PENDING',
      'reportStatus': complete ? 'COMPLETED' : 'PENDING',
      if (complete) ...{
        'schemaVersion': 'gemini-vision-v1',
        'modelVersion': 'gemini-3.8-flash',
        'analysisOutcome': 'DAMAGE_DETECTED',
        'damageSeverity': 'UNKNOWN',
        'damageTypes': ['SCRATCH'],
        'affectedParts': ['FRONT_DOOR'],
        'visualFindings': [
          {
            'damageType': 'SCRATCH',
            'affectedPart': 'FRONT_DOOR',
            'severity': 'UNKNOWN',
            'description': 'Kapı yüzeyinde çizik görünümü izleniyor.',
            'repairNotes': 'Fiziksel incelemeyle netleştirilmelidir.',
            'replacementAssessment': 'UNDETERMINED',
          },
        ],
        'repairRecommendations': [
          {
            'damageType': 'SCRATCH',
            'recommendedAction': 'PROFESSIONAL_INSPECTION',
            'partReplacementRequired': null,
            'affectedParts': ['FRONT_DOOR'],
          },
        ],
        'report': {
          'title': 'Görsel değerlendirme',
          'damageDescription': 'Fotoğraf yorumu.',
        },
      },
    });

class PairService extends InspectionService {
  int detailUploads = 0, overviewUploads = 0, analyses = 0;
  @override
  Future<DamageInspection> uploadImage({
    required int inspectionId,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  }) async {
    detailUploads++;
    return inspection();
  }

  @override
  Future<DamageInspection> uploadContextImage({
    required int inspectionId,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  }) async {
    expect(detailUploads, 1);
    overviewUploads++;
    return inspection();
  }

  @override
  Future<DamageInspection> analyzeInspection(
    int inspectionId, {
    required String vehicleRegion,
  }) async {
    expect(overviewUploads, 1);
    analyses++;
    return inspection(complete: true);
  }

  @override
  Future<DamageInspection> getInspectionById(int id) async =>
      inspection(complete: true);
}

class PairPicker extends ImagePicker {
  PairPicker(this.photos);
  final List<Uint8List> photos;
  int count = 0;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      XFile.fromData(photos[count++], name: 'photo.png', mimeType: 'image/png');
}

Future<Uint8List> photo(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 320, 320), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 320);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

Future<void> pick(WidgetTester tester, String key) async {
  final area = find.byKey(ValueKey(key));
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(
    area,
    200,
    maxScrolls: 40,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(area);
  await tester.pumpAndSettle();
  await tester.tap(area);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Galeriden seç'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Galeriden seç'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);
  testWidgets('both photos are required and submit exactly one analysis', (
    tester,
  ) async {
    await setUiSize(tester, const Size(320, 640));
    final first = await tester.runAsync(() => photo(Colors.red));
    final second = await tester.runAsync(() => photo(Colors.blue));
    final service = PairService();
    await tester.pumpWidget(
      uiTestApp(
        reduceMotion: true,
        textScale: 2,
        home: UploadDamageImageScreen(
          inspection: inspection(),
          imagePicker: PairPicker([first!, second!]),
          inspectionService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pick(tester, 'overview-photo');
    await tester.scrollUntilVisible(
      find.byType(PrimaryButton),
      200,
      maxScrolls: 40,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
    expect(service.detailUploads, 0);
    await pick(tester, 'detail-photo');
    await tester.scrollUntilVisible(
      find.byType(PrimaryButton),
      200,
      maxScrolls: 40,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byType(PrimaryButton));
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(service.detailUploads, 1);
    expect(service.overviewUploads, 1);
    expect(service.analyses, 1);
    expect(find.byType(InspectionResultScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('legacy inspection remains readable without Gemini-only fields', () {
    final old = DamageInspection.fromJson({
      'id': 3,
      'status': 'COMPLETED',
      'damageSeverity': 'NONE',
    });
    expect(old.visualFindings, isEmpty);
    expect(old.needsMorePhotos, isFalse);
    expect(old.damageSeverity, 'NONE');
  });
}
