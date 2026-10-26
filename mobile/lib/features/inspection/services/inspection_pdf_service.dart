import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_locale_controller.dart';
import '../models/damage_inspection.dart';
import '../models/inspection_report_content.dart';
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
    final content = InspectionReportContent(inspection);
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
          pw.SizedBox(height: 10),
          pw.Text(
            'Hasar Analiz Raporu'.tr,
            style: pw.TextStyle(font: bold, fontSize: 24, color: _ink),
          ),
          pw.SizedBox(height: 6),
          pw.Text('${'Rapor No'.tr}: EXP-${inspection.id}', style: _muted(10)),
          pw.SizedBox(height: 10),
          _infoGrid(inspection),
          pw.SizedBox(height: 10),
          _sectionTitle(content.title.tr),
          for (final note in InspectionReportContent.uniqueText([
            inspection.analysisMessage,
            inspection.additionalPhotoGuidance,
          ])) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              note.tr,
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
            ),
          ],
          if (content.noVisibleDamage) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'İşlem Gerekmiyor'.tr,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
          pw.SizedBox(height: 14),
          if (content.hasPrice)
            _priceCard(content)
          else
            pw.Text(
              '${content.priceTitle.tr}: ${content.price.tr}',
              style: _muted(10),
            ),
          for (final note in InspectionReportContent.uniqueText([
            report?.priceInformation,
            report?.priceSourceDescription,
          ])) ...[pw.SizedBox(height: 6), pw.Text(note.tr, style: _muted(9))],
          if (report == null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              (inspection.isReportProcessing
                      ? 'Rapor Hazırlanıyor'
                      : 'Rapor Tamamlanamadı')
                  .tr,
              style: _muted(10),
            ),
            if (inspection.reportMessage?.trim().isNotEmpty == true)
              pw.Text(inspection.reportMessage!, style: _muted(9)),
          ],
          if (content.findings.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('Bulgular ve Onarım'.tr),
            for (final finding in content.findings) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                finding.part.tr,
                style: pw.TextStyle(font: bold, fontSize: 11, color: _ink),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                finding.damageTypes.map((t) => t.tr).join(' · '),
                style: pw.TextStyle(fontSize: 10, color: _brand),
              ),
              for (final note in InspectionReportContent.uniqueText([
                ...finding.observations,
                ...finding.repairs,
              ])) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  note.tr,
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
                ),
              ],
            ],
          ],
          if (content.narrative.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionTitle('Rapor Notları'.tr),
            for (final paragraph in content.narrative) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                paragraph.tr,
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
              ),
            ],
          ],
          pw.SizedBox(height: 10),
          pw.Text(
            content.disclaimer.tr,
            style: pw.TextStyle(fontSize: 9, color: _warning, lineSpacing: 3),
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('Analiz Fotoğrafı'.tr),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 140,
            width: double.infinity,
            child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain),
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
        'HASAR ANALİZ RAPORU'.tr,
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
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: label ? pw.FontWeight.bold : null,
        color: _ink,
      ),
    ),
  );

  pw.Widget _sectionTitle(String value) => pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  );

  pw.Widget _priceCard(InspectionReportContent content) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _successSoft,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          content.priceTitle.tr,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _success,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          content.price,
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
  static final _brand = PdfColor.fromHex('#7C3AED');
  static final _ink = PdfColor.fromHex('#17131F');
  static final _soft = PdfColor.fromHex('#F4F1F8');
  static final _border = PdfColor.fromHex('#DDD7E7');
  static final _success = PdfColor.fromHex('#167A55');
  static final _successSoft = PdfColor.fromHex('#E8F7F0');
  static final _warning = PdfColor.fromHex('#B66A13');
}
