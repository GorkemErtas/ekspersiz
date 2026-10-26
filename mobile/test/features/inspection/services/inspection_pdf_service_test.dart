import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inspection/services/inspection_pdf_service.dart';

import '../../../support/inspection_report_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exports current, historical, no-damage and failed-report records locally',
    () async {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final logo = await rootBundle.load('assets/images/ekspersiz_logo.png');
      final image = logo.buffer.asUint8List(
        logo.offsetInBytes,
        logo.lengthInBytes,
      );
      final cases = {
        'current': reportFixture(),
        'historical': reportFixture({
          'schemaVersion': 'hitl-v1',
          'visualFindings': [],
        }),
        'no-damage': reportFixture({
          'schemaVersion': null,
          'analysisOutcome': null,
          'damageSeverity': 'NONE',
          'damageTypes': ['NO_VISIBLE_DAMAGE'],
          'affectedParts': [],
          'visualFindings': [],
          'repairRecommendations': [],
          'analysisMessage': 'Görünür hasar bulunmadı.',
          'report': {'summary': 'Görünür hasar bulunmadı.'},
        }),
        'failed-report': reportFixture({
          'reportStatus': 'FAILED',
          'report': null,
        }),
        'long': reportFixture({
          'visualFindings': List.generate(
            35,
            (i) => {
              'damageType': 'SCRATCH',
              'affectedPart': 'FRONT_DOOR',
              'severity': 'UNKNOWN',
              'description': 'Bulgu $i: Kapı yüzeyinde çizik görünümü var.',
              'repairNotes':
                  'Onarım $i: Boya derinliği fiziksel incelemeyle belirlenmeli.',
              'replacementAssessment': 'UNDETERMINED',
            },
          ),
        }),
      };
      for (final entry in cases.entries) {
        final bytes = await const InspectionPdfService().buildReport(
          inspection: entry.value,
          imageBytes: image,
          regularFont: regular,
          boldFont: bold,
          logoBytes: image,
        );
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
        expect(bytes.length, greaterThan(1000));
        if (const bool.fromEnvironment('WRITE_REPORT_PREVIEWS')) {
          final directory = Directory('build/report-previews')
            ..createSync(recursive: true);
          File(
            '${directory.path}/report-${entry.key}.pdf',
          ).writeAsBytesSync(bytes);
        }
      }
    },
  );
}
