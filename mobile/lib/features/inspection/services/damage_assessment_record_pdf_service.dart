import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/damage_assessment_record.dart';
import '../models/damage_inspection.dart';
import 'inspection_service.dart';

class DamageAssessmentRecordPdfService {
  const DamageAssessmentRecordPdfService({
    this.inspectionService = const InspectionService(),
  });

  final InspectionService inspectionService;

  Future<void> createAndShare({
    required DamageInspection inspection,
    required DamageAssessmentRecord record,
    Rect? sharePositionOrigin,
  }) async {
    if (!record.isFinalized || record.snapshot == null) {
      throw StateError('PDF yalnızca kesinleştirilmiş tutanak için oluşturulabilir.');
    }

    final results = await Future.wait<Object>([
      inspectionService.getInspectionImage(inspection.id),
      rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      rootBundle.load('assets/images/ekspersiz_logo.png'),
    ]);
    final logo = results[3] as ByteData;
    final bytes = await buildRecord(
      record: record,
      imageBytes: Uint8List.fromList(results[0] as List<int>),
      regularFont: results[1] as ByteData,
      boldFont: results[2] as ByteData,
      logoBytes: logo.buffer.asUint8List(logo.offsetInBytes, logo.lengthInBytes),
    );

    final directory = await getTemporaryDirectory();
    final safeNumber = record.recordNumber.replaceAll(RegExp(r'[^0-9A-Za-z-]'), '');
    final file = File('${directory.path}/EksperSiz_Tutanak_$safeNumber.pdf');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'EksperSiz Araç Hasar Durum ve Beyan Tutanağı',
        text: 'Belge No: ${record.recordNumber}',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<Uint8List> buildRecord({
    required DamageAssessmentRecord record,
    required Uint8List imageBytes,
    required ByteData regularFont,
    required ByteData boldFont,
    required Uint8List logoBytes,
  }) async {
    final snapshot = record.snapshot;
    if (!record.isFinalized || snapshot == null) {
      throw StateError('Kesinleştirilmiş tutanak verisi bulunamadı.');
    }
    final vehicle = _map(snapshot['vehicle']);
    final analysis = _map(snapshot['analysis']);
    final report = _nullableMap(snapshot['report']);
    final regular = pw.Font.ttf(regularFont);
    final bold = pw.Font.ttf(boldFont);
    final document = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => _header(logoBytes, bold),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('EksperSiz • Kullanıcı beyanı + AI görünür hasar analizi', style: _muted(7.5)),
            pw.Text('${context.pageNumber} / ${context.pagesCount}', style: _muted(7.5)),
          ],
        ),
        build: (_) => [
          pw.SizedBox(height: 16),
          pw.Text('Araç Hasar Durum ve Beyan Tutanağı',
              style: pw.TextStyle(font: bold, fontSize: 22, color: _ink)),
          pw.SizedBox(height: 5),
          pw.Text('Belge No: ${record.recordNumber}  •  Sürüm: ${record.documentVersion}',
              style: _muted(9)),
          pw.SizedBox(height: 18),
          _section('Araç Bilgileri', bold),
          pw.SizedBox(height: 7),
          _grid([
            ['Plaka', _text(vehicle['plate']), 'Araç', '${_text(vehicle['brand'])} ${_text(vehicle['model'])}'],
            ['Model Yılı', _text(vehicle['modelYear']), 'Kilometre', '${_text(vehicle['mileage'])} km'],
          ], bold),
          pw.SizedBox(height: 16),
          _section('Olay Bilgileri ve Kullanıcı Beyanı', bold),
          pw.SizedBox(height: 7),
          _grid([
            ['Olay Tarihi', _formatIso(snapshot['incidentDateTime']), 'İl / İlçe',
              [_text(snapshot['incidentCity']), _text(snapshot['incidentDistrict'])].where((e) => e.isNotEmpty).join(' / ')],
            ['Adres / Konum', _fallback(snapshot['incidentAddress']), 'Beyan Sahibi', _text(snapshot['declarantFullName'])],
          ], bold),
          pw.SizedBox(height: 8),
          _textCard(_text(snapshot['incidentDescription'])),
          pw.SizedBox(height: 16),
          _section('İnceleme Fotoğrafı', bold),
          pw.SizedBox(height: 7),
          pw.Container(
            height: 230,
            width: double.infinity,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _border), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain),
            ),
          ),
          pw.SizedBox(height: 16),
          _section('AI Teknik Değerlendirmesi', bold),
          pw.SizedBox(height: 7),
          _grid([
            ['Hasar Seviyesi', _severity(_text(analysis['damageSeverity'])), 'Güven Skoru', _percent(analysis['confidenceScore'])],
            ['Analiz Tarihi', _formatIso(analysis['completedAt']), 'İnceleme No', _text(analysis['inspectionId'])],
          ], bold),
          if (_text(analysis['analysisMessage']).isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _textCard(_text(analysis['analysisMessage'])),
          ],
          if (report != null) ...[
            pw.SizedBox(height: 14),
            _section('Detaylı AI Raporu', bold),
            pw.SizedBox(height: 7),
            _textCard([
              _text(report['summary']),
              _text(report['damageDescription']),
              _text(report['repairRecommendation']),
            ].where((e) => e.isNotEmpty).join('\n\n')),
            if (_number(report['estimatedMaximumPrice']) > 0) ...[
              pw.SizedBox(height: 8),
              _textCard(
                'Tahmini onarım aralığı: ${_money(_number(report['estimatedMinimumPrice']))} - '
                '${_money(_number(report['estimatedMaximumPrice']))} ${_text(report['currency'])}',
              ),
            ],
          ],
          pw.SizedBox(height: 16),
          _section('Belge Doğrulama Bilgisi', bold),
          pw.SizedBox(height: 7),
          _textCard(
            'Kesinleştirme: ${_formatDate(record.finalizedAt)}\n'
            'SHA-256: ${record.contentHash ?? '-'}',
            mono: true,
          ),
          pw.SizedBox(height: 14),
          _warning(
            'Bu belge EksperSiz tarafından kullanıcı beyanı ve yapay zekâ destekli '
            'görüntü analizi kullanılarak oluşturulmuştur. Yetkili sigorta eksperi '
            'raporu, kolluk trafik kazası tespit tutanağı veya SBM Maddi Hasarlı '
            'Trafik Kazası Tespit Tutanağı yerine geçmez.',
            bold,
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _header(Uint8List logoBytes, pw.Font bold) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Row(children: [
        pw.Container(width: 38, height: 38, padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(color: _brand, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Image(pw.MemoryImage(logoBytes))),
        pw.SizedBox(width: 9),
        pw.Text('EksperSiz', style: pw.TextStyle(font: bold, fontSize: 18, color: _ink)),
      ]),
      pw.Text('KESİNLEŞTİRİLMİŞ TUTANAK',
          style: pw.TextStyle(font: bold, fontSize: 8.5, color: _brand)),
    ],
  );

  pw.Widget _section(String text, pw.Font bold) =>
      pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 12.5, color: _ink));

  pw.Widget _grid(List<List<String>> rows, pw.Font bold) => pw.Table(
    border: pw.TableBorder.all(color: _border, width: .7),
    children: rows.map((r) => pw.TableRow(children: [
      _cell(r[0], bold, true), _cell(r[1], bold, false),
      _cell(r[2], bold, true), _cell(r[3], bold, false),
    ])).toList(),
  );

  pw.Widget _cell(String text, pw.Font bold, bool label) => pw.Container(
    color: label ? _soft : null,
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(text.isEmpty ? '-' : text,
      style: pw.TextStyle(font: label ? bold : null, fontSize: 8.7, color: _ink)),
  );

  pw.Widget _textCard(String text, {bool mono = false}) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(7),
      border: pw.Border.all(color: _border)),
    child: pw.Text(text.isEmpty ? '-' : text,
      style: pw.TextStyle(fontSize: mono ? 7.5 : 9, lineSpacing: 2.5)),
  );

  pw.Widget _warning(String text, pw.Font bold) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromHex('#FFF7E8'),
      border: pw.Border.all(color: PdfColor.fromHex('#B66A13')),
      borderRadius: pw.BorderRadius.circular(7),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Önemli Bilgilendirme',
        style: pw.TextStyle(font: bold, fontSize: 9.5, color: PdfColor.fromHex('#8A4B08'))),
      pw.SizedBox(height: 4),
      pw.Text(text, style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 2)),
    ]),
  );

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static Map<String, dynamic>? _nullableMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;
  static String _text(dynamic value) => value?.toString().trim() ?? '';
  static String _fallback(dynamic value) => _text(value).isEmpty ? '-' : _text(value);
  static double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(_text(value)) ?? 0;
  static String _percent(dynamic value) {
    final n = _number(value);
    return n <= 0 ? '-' : '%${(n * 100).round()}';
  }
  static String _formatIso(dynamic value) {
    final date = DateTime.tryParse(_text(value));
    return _formatDate(date);
  }
  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
  }
  static String _money(double value) =>
      value.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  static String _severity(String value) => switch (value) {
    'NONE' => 'Görünür Hasar Tespit Edilmedi',
    'MINOR' => 'Hafif',
    'MODERATE' => 'Orta',
    'SEVERE' => 'Ağır',
    _ => value.isEmpty ? 'Belirsiz' : value,
  };
  static pw.TextStyle _muted(double size) => pw.TextStyle(fontSize: size, color: PdfColors.grey600);

  static final _brand = PdfColor.fromHex('#7C3AED');
  static final _ink = PdfColor.fromHex('#17131F');
  static final _soft = PdfColor.fromHex('#F4F1F8');
  static final _border = PdfColor.fromHex('#DDD7E7');
}
