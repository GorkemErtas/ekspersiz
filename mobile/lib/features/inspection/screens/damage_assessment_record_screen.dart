import 'package:flutter/material.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../models/damage_assessment_record.dart';
import '../models/damage_inspection.dart';
import '../services/damage_assessment_record_service.dart';
import '../services/damage_assessment_record_pdf_service.dart';

class DamageAssessmentRecordScreen extends StatefulWidget {
  const DamageAssessmentRecordScreen({
    super.key,
    required this.inspection,
    this.service = const DamageAssessmentRecordService(),
  });

  final DamageInspection inspection;
  final DamageAssessmentRecordService service;

  @override
  State<DamageAssessmentRecordScreen> createState() =>
      _DamageAssessmentRecordScreenState();
}

class _DamageAssessmentRecordScreenState
    extends State<DamageAssessmentRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _city;
  final _district = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _declarant = TextEditingController();

  DamageAssessmentRecord? _record;
  late DateTime _incidentDateTime;
  bool _loading = true;
  bool _saving = false;
  bool _sharing = false;
  final DamageAssessmentRecordPdfService _pdfService =
      const DamageAssessmentRecordPdfService();

  bool get _readOnly => _record?.isFinalized == true;

  @override
  void initState() {
    super.initState();
    _city = TextEditingController(text: widget.inspection.locationCity);
    _incidentDateTime =
        widget.inspection.completedAt ?? DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _city.dispose();
    _district.dispose();
    _address.dispose();
    _description.dispose();
    _declarant.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final record = await widget.service.get(widget.inspection.id);
      if (!mounted) return;
      if (record != null) {
        _apply(record);
      }
    } catch (exception) {
      if (mounted) _showError(exception, 'Tutanak bilgileri alınamadı.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(DamageAssessmentRecord record) {
    _record = record;
    _incidentDateTime = record.incidentDateTime;
    _city.text = record.incidentCity;
    _district.text = record.incidentDistrict ?? '';
    _address.text = record.incidentAddress ?? '';
    _description.text = record.incidentDescription;
    _declarant.text = record.declarantFullName;
  }

  Future<void> _pickDateTime() async {
    if (_readOnly) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _incidentDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_incidentDateTime),
    );
    if (time == null) return;
    setState(() {
      _incidentDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<DamageAssessmentRecord?> _save() async {
    if (!_formKey.currentState!.validate()) return null;
    setState(() => _saving = true);
    try {
      final existing = _record;
      final record = existing == null
          ? await widget.service.create(
              inspectionId: widget.inspection.id,
              incidentDateTime: _incidentDateTime,
              incidentCity: _city.text,
              incidentDistrict: _district.text,
              incidentAddress: _address.text,
              incidentDescription: _description.text,
              declarantFullName: _declarant.text,
            )
          : await widget.service.update(
              inspectionId: widget.inspection.id,
              incidentDateTime: _incidentDateTime,
              incidentCity: _city.text,
              incidentDistrict: _district.text,
              incidentAddress: _address.text,
              incidentDescription: _description.text,
              declarantFullName: _declarant.text,
            );
      if (!mounted) return record;
      setState(() => _record = record);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Tutanak taslağı kaydedildi.')),
      );
      return record;
    } catch (exception) {
      if (mounted) _showError(exception, 'Tutanak kaydedilemedi.');
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finalize() async {
    final saved = await _save();
    if (saved == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Tutanağı kesinleştir?'),
        content: const AppText(
          'Kesinleştirilen tutanak daha sonra düzenlenemez. '
          'Bilgilerin doğru olduğundan emin olun.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const AppText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const AppText('Kesinleştir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final finalized = await widget.service.finalize(widget.inspection.id);
      if (!mounted) return;
      setState(() => _apply(finalized));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Tutanak kesinleştirildi.')),
      );
    } catch (exception) {
      if (mounted) _showError(exception, 'Tutanak kesinleştirilemedi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sharePdf() async {
    final record = _record;
    if (record == null || !record.isFinalized || _sharing) return;
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      await _pdfService.createAndShare(
        inspection: widget.inspection,
        record: record,
        sharePositionOrigin: origin,
      );
    } catch (exception) {
      if (mounted) _showError(exception, 'Tutanak PDF dosyası oluşturulamadı.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showError(Object exception, String fallback) {
    final message =
        exception is ApiException ? exception.message : fallback;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(message)));
  }

  String _dateTimeText() {
    final d = _incidentDateTime;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}  '
        '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return Scaffold(
      appBar: AppBar(title: const AppText('Hasar Durum Tutanağı')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                      children: [
                        _InfoCard(
                          title: record?.isFinalized == true
                              ? 'Tutanak kesinleştirildi'
                              : 'Araç Hasar Durum Tespit Tutanağı',
                          text: record?.isFinalized == true
                              ? 'Belge No: ${record!.recordNumber}'
                              : 'Olay bilgilerini kendi beyanınıza göre girin. '
                                'AI analizi olayın nasıl gerçekleştiğini belirlemez.',
                          finalized: record?.isFinalized == true,
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: 'Araç',
                          child: AppText(
                            '${widget.inspection.vehiclePlate} · '
                            '${widget.inspection.vehicleBrand} '
                            '${widget.inspection.vehicleModel} · '
                            '${widget.inspection.vehicleModelYear}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: 'Olay Bilgileri',
                          child: Column(
                            children: [
                              InkWell(
                                onTap: _readOnly ? null : _pickDateTime,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Olay tarihi ve saati',
                                    suffixIcon: Icon(Icons.event_outlined),
                                  ),
                                  child: AppText(_dateTimeText()),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _field(_city, 'İl', isRequired: true),
                              const SizedBox(height: 12),
                              _field(_district, 'İlçe'),
                              const SizedBox(height: 12),
                              _field(_address, 'Adres / Konum', maxLines: 2),
                              const SizedBox(height: 12),
                              _field(
                                _description,
                                'Olay açıklaması / kullanıcı beyanı',
                                isRequired: true,
                                maxLines: 5,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: 'Beyan Sahibi',
                          child: _field(
                            _declarant,
                            'Ad Soyad',
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _LegalNotice(),
                        const SizedBox(height: 20),
                        if (!_readOnly) ...[
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const AppText('Taslağı Kaydet'),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _saving ? null : _finalize,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.verified_outlined),
                            label: const AppText('Tutanağı Kesinleştir'),
                          ),
                        ,
                        ] else ...[
                          FilledButton.icon(
                            onPressed: _sharing ? null : _sharePdf,
                            icon: _sharing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined),
                            label: AppText(
                              _sharing
                                  ? 'PDF hazırlanıyor...'
                                  : 'Tutanağı PDF Olarak Paylaş',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: _readOnly,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label),
      validator: isRequired
          ? (value) => value == null || value.trim().isEmpty
              ? 'Bu alan zorunludur.'
              : null
          : null,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.text,
    required this.finalized,
  });
  final String title;
  final String text;
  final bool finalized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: finalized
            ? AppTheme.successSoftFor(context)
            : colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          AppText(text),
        ],
      ),
    );
  }
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Belge Hakkında',
      child: AppText(
        'Bu belge kullanıcı beyanı ve yapay zekâ destekli görüntü analizi '
        'kullanılarak oluşturulur. Yetkili sigorta eksperi raporu, kolluk '
        'trafik kazası tespit tutanağı veya SBM Maddi Hasarlı Trafik Kazası '
        'Tespit Tutanağı yerine geçmez.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
      ),
    );
  }
}
