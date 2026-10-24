import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inspection/models/damage_repair_recommendation.dart';
import 'package:mobile/features/inspection/models/vision_class_catalog.dart';

void main() {
  test(
    'all current classes have Turkish labels while source identity is retained',
    () {
      for (final entry in {
        'MISSING_PART': 'Eksik parça',
        'Missing part': 'Eksik parça',
        'CRACKED': 'Çatlak',
        'CORROSION': 'Korozyon',
        'FLAKING': 'Boya soyulması',
        'PAINT_CHIP': 'Boya kopması',
        'BACK_BUMPER': 'Arka tampon',
        'Back-bumper': 'Arka tampon',
        'BACK_WINDSHIELD': 'Arka cam',
      }.entries) {
        expect(VisionClassCatalog.label(entry.key), entry.value);
      }
      expect(VisionClassCatalog.label('invented-class'), isNull);
    },
  );

  test(
    'unknown replacement requirement is preserved and legacy booleans stay readable',
    () {
      final current = DamageRepairRecommendation.fromJson({
        'damageType': 'CRACKED',
        'recommendedAction': 'PROFESSIONAL_INSPECTION',
        'partReplacementRequired': null,
        'affectedParts': ['BACK_BUMPER'],
      });
      expect(current.partReplacementRequired, isNull);
      expect(current.damageType, 'CRACKED');
      expect(current.affectedParts.single, 'BACK_BUMPER');
      expect(
        DamageRepairRecommendation.fromJson({
          'damageType': 'CRACK',
          'recommendedAction': 'PART_REPAIR',
        }).partReplacementRequired,
        false,
      );
    },
  );
}
