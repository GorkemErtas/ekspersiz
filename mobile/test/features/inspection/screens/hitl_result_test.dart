import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/inspection/models/damage_inspection.dart';
import 'package:mobile/features/inspection/screens/inspection_result_screen.dart';

import '../../../support/ui_mock_api.dart';
import '../../../support/ui_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installOfflineTestFonts);
  setUp(initializeUiSession);

  testWidgets(
    'current damage classes and unknown replacement appear without a false repair claim',
    (tester) async {
      final inspection = DamageInspection.fromJson({
        'id': 77,
        'vehicleId': 1,
        'userId': 1,
        'vehiclePlate': '34 TEST',
        'vehicleBrand': 'Honda',
        'vehicleModel': 'Civic',
        'vehicleModelYear': 2024,
        'vehicleMileage': 1000,
        'status': 'COMPLETED',
        'reportStatus': 'COMPLETED',
        'schemaVersion': 'hitl-v1',
        'modelVersion': 'widget-fixture',
        'damageSeverity': 'UNKNOWN',
        'damageTypes': ['CRACKED', 'CORROSION'],
        'affectedParts': ['BACK_BUMPER'],
        'confidenceScore': 0.8,
        'analysisMessage': 'Fiziksel inceleme gerekir.',
        'repairRecommendations': [
          {
            'damageType': 'CRACKED',
            'recommendedAction': 'PROFESSIONAL_INSPECTION',
            'partReplacementRequired': null,
            'affectedParts': ['BACK_BUMPER'],
          },
        ],
        'report': {
          'title': 'Ön değerlendirme',
          'summary': 'Fiziksel inceleme gerekli.',
          'estimatedMinimumPrice': 100,
          'estimatedMaximumPrice': 200,
          'currency': 'TRY',
        },
        'locationCity': 'İstanbul',
      });
      await setUiSize(tester, const Size(390, 844));
      await http.runWithClient(() async {
        await tester.pumpWidget(
          uiTestApp(
            home: InspectionResultScreen(inspection: inspection),
            brightness: Brightness.light,
            textScale: 1,
            reduceMotion: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Çatlak'), findsWidgets);
        expect(find.text('Korozyon'), findsWidgets);
        expect(find.text('Arka tampon'), findsWidgets);
        expect(
          find.text(
            'Parça değişimi gereksinimi fiziksel incelemeyle belirlenecek.',
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Tahmini Fiziksel İnceleme Maliyeti'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Tahmini Fiziksel İnceleme Maliyeti'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => MockClient((request) async => uiJsonResponse({})));
    },
  );
}
