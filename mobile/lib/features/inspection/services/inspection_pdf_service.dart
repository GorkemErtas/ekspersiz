import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_locale_controller.dart';
import '../models/damage_inspection.dart';
import 'inspection_service.dart';

class InspectionPdfService {
  const InspectionPdfService({
    this.inspectionService = const InspectionService(),
  });

  final InspectionService inspectionService;

  Future<void> createAndShare(
    DamageInspection inspection, {
    Rect? sharePositionOrigin,
  }) async {
    if (!inspection.isCompleted) {
      throw StateError(
        'PDF raporu yalnızca tamamlanan analizler için oluşturulabilir.',
      );
    }

    final results = await Future.wait<Object>([
      inspectionService.getInspectionImage(inspection.id),
      rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      rootBundle.load('assets/images/ekspersiz_logo.png'),
    ]);
    final logoData = results[3] as ByteData;
    final bytes = await buildReport(
      inspection: inspection,
      imageBytes: Uint8List.fromList(results[0] as List<int>),
      regularFont: results[1] as ByteData,
      boldFont: results[2] as ByteData,
      logoBytes: logoData.buffer.asUint8List(
        logoData.offsetInBytes,
        logoData.lengthInBytes,
      ),
    );

    final directory = await getTemporaryDirectory();
    final plate = inspection.vehiclePlate.replaceAll(
      RegExp(r'[^0-9A-Za-z]'),
      '',
    );
    final file = File(
      '${directory.path}/EksperSiz_${plate}_${inspection.id}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'EksperSiz Araç İnceleme Raporu'.tr,
        text:
            '${inspection.vehiclePlate} ${'plakalı araç için EksperSiz AI inceleme raporu.'.tr}',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<Uint8List> buildReport({
    required DamageInspection inspection,
    required Uint8List imageBytes,
    required ByteData regularFont,
    required ByteData boldFont,
    required Uint8List logoBytes,
  }) async {
    final regular = pw.Font.ttf(regularFont);
    final bold = pw.Font.ttf(boldFont);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final noDamage = inspection.damageSeverity == 'NONE';
    final report = inspection.report;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => _header(logoBytes),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'EksperSiz • AI destekli görünür hasar analizi'.tr,
              style: _muted(8),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: _muted(8),
            ),
          ],
        ),
        build: (_) => [
          pw.SizedBox(height: 18),
          pw.Text(
            (noDamage
                    ? 'Görünür Hasar Tespit Edilmedi'
                    : 'Araç İnceleme Raporu')
                .tr,
            style: pw.TextStyle(font: bold, fontSize: 24, color: _ink),
          ),
          pw.SizedBox(height: 6),
          pw.Text('${'Rapor No'.tr}: EXP-${inspection.id}', style: _muted(10)),
          pw.SizedBox(height: 20),
          _infoGrid(inspection),
          pw.SizedBox(height: 20),
          _sectionTitle('İnceleme Fotoğrafı'.tr),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 245,
            width: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 10,
              verticalRadius: 10,
              child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.cover),
            ),
          ),
          pw.SizedBox(height: 20),
          _resultCard(inspection, noDamage),
          if (!noDamage && inspection.damageTypes.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _listSection(
              'Tespit Edilen Hasarlar'.tr,
              inspection.damageTypes.map(_damageLabel).toList(),
            ),
          ],
          if (!noDamage && inspection.affectedParts.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _listSection(
              'Etkilenen Parçalar'.tr,
              inspection.affectedParts.map(_partLabel).toList(),
            ),
          ],
          if (!noDamage && inspection.repairRecommendations.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _listSection(
              'Onarım Önerileri'.tr,
              inspection.repairRecommendations
                  .map((item) => _repairLabel(item.recommendedAction))
                  .toSet()
                  .toList(),
            ),
          ],
          if (report != null) ...[
            pw.SizedBox(height: 18),
            _sectionTitle('AI Rapor Özeti'.tr),
            pw.SizedBox(height: 8),
            _textCard(
              [
                report.summary,
                report.damageDescription,
                report.repairRecommendation,
              ].where((text) => text.trim().isNotEmpty).join('\n\n'),
            ),
          ],
          if (!noDamage &&
              report != null &&
              report.estimatedMaximumPrice > 0) ...[
            pw.SizedBox(height: 14),
            _priceCard(
              report.estimatedMinimumPrice,
              report.estimatedMaximumPrice,
              report.currency,
            ),
          ],
          pw.SizedBox(height: 18),
          _sectionTitle('Bilgilendirme'.tr),
          pw.SizedBox(height: 8),
          _textCard(
            report?.disclaimer.trim().isNotEmpty == true
                ? report!.disclaimer
                : 'Bu rapor yalnızca yüklenen fotoğraftaki görünür alanların yapay zekâ ile değerlendirilmesine dayanır. Mekanik kontrol veya profesyonel ekspertiz garantisi değildir.'
                    .tr,
            accent: _warning,
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _header(Uint8List logoBytes) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Row(
        children: [
          pw.Container(
            width: 42,
            height: 42,
            decoration: pw.BoxDecoration(
              color: _brand,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            'EksperSiz',
            style: pw.TextStyle(
              fontSize: 19,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
      pw.Text(
        'ARAÇ İNCELEME RAPORU'.tr,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _brand,
        ),
      ),
    ],
  );

  pw.Widget _infoGrid(DamageInspection inspection) {
    final date = inspection.completedAt ?? inspection.createdAt;
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: .7),
      children: [
        _infoRow(
          'Araç'.tr,
          '${inspection.vehicleBrand} ${inspection.vehicleModel}',
          'Plaka'.tr,
          inspection.vehiclePlate,
        ),
        _infoRow(
          'Model Yılı'.tr,
          '${inspection.vehicleModelYear}',
          'Kilometre'.tr,
          '${inspection.vehicleMileage} km',
        ),
        _infoRow(
          'Tarih'.tr,
          _formatDate(date),
          'Konum'.tr,
          inspection.locationCity,
        ),
      ],
    );
  }

  pw.TableRow _infoRow(String a, String b, String c, String d) => pw.TableRow(
    children: [
      _cell(a, label: true),
      _cell(b),
      _cell(c, label: true),
      _cell(d),
    ],
  );

  pw.Widget _cell(String text, {bool label = false}) => pw.Container(
    color: label ? _soft : null,
    padding: const pw.EdgeInsets.all(9),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: label ? pw.FontWeight.bold : null,
        color: _ink,
      ),
    ),
  );

  pw.Widget _resultCard(
    DamageInspection inspection,
    bool noDamage,
  ) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: noDamage ? _successSoft : _soft,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: noDamage ? _success : _brand, width: 1),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _severityLabel(inspection.damageSeverity),
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: noDamage ? _success : _ink,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          noDamage
              ? 'Gönderilen görüntüde görünür hasar tespit edilmedi. Bu sonuç mekanik veya profesyonel ekspertiz garantisi değildir.'
                  .tr
              : (inspection.analysisMessage ?? 'Görsel analiz tamamlandı.').tr,
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
        ),
      ],
    ),
  );

  pw.Widget _listSection(String title, List<String> values) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(title),
      pw.SizedBox(height: 7),
      ...values.map(
        (value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '• ',
                style: pw.TextStyle(
                  color: _brand,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Expanded(
                child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  pw.Widget _sectionTitle(String value) => pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  );

  pw.Widget _textCard(String value, {PdfColor? accent}) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(13),
    decoration: pw.BoxDecoration(
      color: _soft,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: accent ?? _brand, width: 1),
    ),
    child: pw.Text(
      value,
      style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 3),
    ),
  );

  pw.Widget _priceCard(double minimum, double maximum, String currency) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _successSoft,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Tahmini Onarım Aralığı'.tr,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _success,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              '${_money(minimum)} - ${_money(maximum)} $currency',
              style: pw.TextStyle(
                fontSize: 17,
                fontWeight: pw.FontWeight.bold,
                color: _success,
              ),
            ),
          ],
        ),
      );

  static pw.TextStyle _muted(double size) =>
      pw.TextStyle(fontSize: size, color: PdfColors.grey600);
  static String _formatDate(DateTime? date) => date == null
      ? '-'
      : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  static String _money(double value) => value
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  static String _severityLabel(String? value) => (switch (value) {
    'NONE' => 'Görünür Hasar Tespit Edilmedi',
    'MINOR' => 'Hafif Seviye Hasar',
    'MODERATE' => 'Orta Seviye Hasar',
    'SEVERE' => 'Ağır Seviye Hasar',
    _ => 'Hasar Seviyesi Belirsiz',
  }).tr;
  static String _damageLabel(String value) => (switch (value) {
    'SCRATCH' => 'Çizik',
    'PAINT_DAMAGE' => 'Boya Hasarı',
    'DENT' => 'Göçük',
    'CRACK' => 'Çatlak',
    'BROKEN_PART' => 'Kırık Parça',
    'BROKEN_GLASS' => 'Kırık Cam',
    'DEFORMATION' => 'Deformasyon',
    _ => value,
  }).tr;
  static String _partLabel(String value) => (switch (value) {
    'FRONT_BUMPER' => 'Ön Tampon',
    'REAR_BUMPER' => 'Arka Tampon',
    'FRONT_DOOR' => 'Ön Kapı',
    'REAR_DOOR' => 'Arka Kapı',
    'FRONT_WHEEL' => 'Ön Tekerlek',
    'REAR_WHEEL' => 'Arka Tekerlek',
    'FRONT_WINDOW' => 'Ön Yan Cam',
    'REAR_WINDOW' => 'Arka Yan Cam',
    'HOOD' => 'Kaput',
    'TRUNK' => 'Bagaj Kapağı',
    'FENDER' => 'Çamurluk',
    'QUARTER_PANEL' => 'Arka Çamurluk Paneli',
    'ROCKER_PANEL' => 'Marşpiyel',
    'GRILLE' => 'Ön Izgara',
    'ROOF' => 'Tavan',
    'WINDSHIELD' => 'Ön Cam',
    'REAR_WINDSHIELD' => 'Arka Cam',
    'HEADLIGHT' => 'Far',
    'TAIL_LIGHT' => 'Arka Stop Lambası',
    'MIRROR' => 'Yan Ayna',
    'LICENSE_PLATE' => 'Plaka',
    _ => value,
  }).tr;
  static String _repairLabel(String value) => (switch (value) {
    'NO_ACTION' => 'İşlem Gerekmiyor',
    'POLISHING' => 'Pasta / Cila',
    'PAINT_TOUCH_UP' => 'Lokal Boya Rötuşu',
    'FULL_PAINTING' => 'Tam Boyama',
    'PAINTLESS_DENT_REPAIR' => 'Boyasız Göçük Düzeltme',
    'DENT_REPAIR' => 'Göçük Düzeltme',
    'PLASTIC_REPAIR' => 'Plastik Onarımı',
    'PART_REPAIR' => 'Parça Onarımı',
    'PART_REPLACEMENT' => 'Parça Değişimi',
    'GLASS_REPAIR' => 'Cam Onarımı',
    'GLASS_REPLACEMENT' => 'Cam Değişimi',
    'HEADLIGHT_REPAIR' => 'Far Onarımı',
    'HEADLIGHT_REPLACEMENT' => 'Far Değişimi',
    _ => value,
  }).tr;

  static final _brand = PdfColor.fromHex('#7C3AED');
  static final _ink = PdfColor.fromHex('#17131F');
  static final _soft = PdfColor.fromHex('#F4F1F8');
  static final _border = PdfColor.fromHex('#DDD7E7');
  static final _success = PdfColor.fromHex('#167A55');
  static final _successSoft = PdfColor.fromHex('#E8F7F0');
  static final _warning = PdfColor.fromHex('#B66A13');
}
