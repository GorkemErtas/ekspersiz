import 'package:mobile/core/localization/app_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/app_motion.dart';

import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'analyzing_screen.dart';

class UploadDamageImageScreen extends StatefulWidget {
  const UploadDamageImageScreen({
    super.key,
    required this.inspection,
    this.imagePicker,
    this.inspectionService = const InspectionService(),
  });

  final DamageInspection inspection;
  final ImagePicker? imagePicker;
  final InspectionService inspectionService;

  @override
  State<UploadDamageImageScreen> createState() =>
      _UploadDamageImageScreenState();
}

class _UploadDamageImageScreenState extends State<UploadDamageImageScreen> {
  static const int _maxImageSizeBytes = 10 * 1024 * 1024;

  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();

  InspectionService get _inspectionService => widget.inspectionService;

  Uint8List? _selectedImageBytes;

  String? _selectedContentType;
  String? _selectedFilename;

  Uint8List? _overviewBytes;
  String? _overviewContentType;
  String? _overviewFilename;
  bool _isPicking = false;
  bool _isUploading = false;

  Future<void> _pickImage(ImageSource source, {bool overview = false}) async {
    if (_isPicking || _isUploading) return;
    _isPicking = true;
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image == null || !mounted) {
        return;
      }

      // Reject oversized files before allocating their full byte buffer.
      // Keep the byte-length check below in case the file changes after stat.
      final fileLength = await image.length();
      if (!mounted) return;
      if (fileLength > _maxImageSizeBytes) {
        _showMessage('Fotoğraf boyutu 10 MB’dan büyük olamaz.');
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        _showMessage('Seçilen fotoğraf boş veya okunamıyor.');
        return;
      }

      if (bytes.length > _maxImageSizeBytes) {
        _showMessage('Fotoğraf boyutu 10 MB’dan büyük olamaz.');
        return;
      }

      final detectedContentType = _detectContentType(bytes);

      if (detectedContentType == null) {
        _showMessage(
          'Seçilen dosya geçerli bir JPG, PNG veya WEBP fotoğraf değil.',
        );
        return;
      }

      final correctedFilename = _buildCorrectFilename(
        originalFilename: image.name,
        contentType: detectedContentType,
      );

      setState(() {
        if (overview) {
          _overviewBytes = bytes;
          _overviewContentType = detectedContentType;
          _overviewFilename = correctedFilename;
        } else {
          _selectedImageBytes = bytes;
          _selectedContentType = detectedContentType;
          _selectedFilename = correctedFilename;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Fotoğraf seçilemedi.');
    } finally {
      _isPicking = false;
    }
  }

  String? _detectContentType(Uint8List bytes) {
    if (_isJpeg(bytes)) {
      return 'image/jpeg';
    }

    if (_isPng(bytes)) {
      return 'image/png';
    }

    if (_isWebp(bytes)) {
      return 'image/webp';
    }

    return null;
  }

  bool _isJpeg(Uint8List bytes) {
    return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  }

  bool _isPng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  bool _isWebp(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }

  String _buildCorrectFilename({
    required String originalFilename,
    required String contentType,
  }) {
    final baseName = _removeExtension(originalFilename);

    final extension = switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };

    return '$baseName.$extension';
  }

  String _removeExtension(String filename) {
    final lastDotIndex = filename.lastIndexOf('.');

    if (lastDotIndex <= 0) {
      return filename;
    }

    return filename.substring(0, lastDotIndex);
  }

  Future<void> _uploadImage() async {
    if (_isUploading) return;
    final imageBytes = _selectedImageBytes;

    final contentType = _selectedContentType;

    final filename = _selectedFilename;
    final overviewBytes = _overviewBytes;
    final overviewContentType = _overviewContentType;
    final overviewFilename = _overviewFilename;

    if (imageBytes == null || contentType == null || filename == null) {
      _showMessage('Lütfen önce bir fotoğraf seçin.');
      return;
    }
    if (overviewBytes == null ||
        overviewContentType == null ||
        overviewFilename == null) {
      _showMessage(
        'Genel görünüm ve yakın detay için iki ayrı fotoğraf seçin.',
      );
      return;
    }
    if (listEquals(imageBytes, overviewBytes)) {
      _showMessage(
        'Genel görünüm ve yakın detay için iki farklı fotoğraf kullanın.',
      );
      return;
    }

    if (imageBytes.isEmpty) {
      _showMessage('Seçilen fotoğraf boş veya okunamıyor.');
      return;
    }

    if (imageBytes.length > _maxImageSizeBytes) {
      _showMessage('Fotoğraf boyutu 10 MB’dan büyük olamaz.');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await _inspectionService.uploadImage(
        inspectionId: widget.inspection.id,
        imageBytes: imageBytes,
        filename: filename,
        contentType: contentType,
      );
      // Upload the detail first: replacing it invalidates any old overview on the server.
      final updatedInspection = await _inspectionService.uploadContextImage(
        inspectionId: widget.inspection.id,
        imageBytes: overviewBytes,
        filename: overviewFilename,
        contentType: overviewContentType,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AnalyzingScreen(
            inspection: updatedInspection,
            vehicleRegion: '',
            inspectionService: _inspectionService,
          ),
        ),
      );
    } catch (exception) {
      if (!mounted) {
        return;
      }

      final message = exception is ApiException
          ? exception.message
          : 'Fotoğraf yüklenemedi.';

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(message)));
  }

  void _showImageSourceSheet({bool overview = false}) {
    if (_isUploading) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        final textTheme = Theme.of(context).textTheme;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Fotoğraf kaynağı',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 6),

              AppText(
                'Hasarı ve çevresindeki araç parçasını gösteren fotoğrafınızı seçin.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 20),

              _ImageSourceOption(
                icon: Icons.photo_camera_outlined,
                title: 'Kamera ile çek',
                subtitle: 'Yeni bir fotoğraf çekin',
                onTap: () {
                  Navigator.of(context).pop();

                  _pickImage(ImageSource.camera, overview: overview);
                },
              ),

              const SizedBox(height: 10),

              _ImageSourceOption(
                icon: Icons.photo_library_outlined,
                title: 'Galeriden seç',
                subtitle: 'Mevcut bir fotoğraf kullanın',
                onTap: () {
                  Navigator.of(context).pop();

                  _pickImage(ImageSource.gallery, overview: overview);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatFileSize([Uint8List? selected]) {
    final bytes = selected ?? _selectedImageBytes;

    if (bytes == null) {
      return '';
    }

    final mb = bytes.length / (1024 * 1024);

    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }

    final kb = bytes.length / 1024;

    return '${kb.toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    final hasImage = _selectedImageBytes != null;
    final hasBothImages = hasImage && _overviewBytes != null;

    return Scaffold(
      appBar: AppBar(title: const AppText('Hasar Fotoğrafı')),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),

            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageInset,
                AppTheme.spacingM,
                AppTheme.pageInset,
                36,
              ),

              children: [
                const AppPageHeader(
                  icon: Icons.image_search_rounded,
                  title: 'Hasarı iki fotoğrafla gösterin',
                  subtitle:
                      'Önce araç parçasını ve hasarın çevresini gösteren genel görünümü, '
                      'ardından aynı hasarın net yakın detayını ekleyin.',
                  badge: 'İKİ FOTOĞRAF',
                ),

                const SizedBox(height: AppTheme.spacingL),

                AppCard(
                  padding: const EdgeInsets.all(18),

                  child: Row(
                    children: [
                      const AppIconBox(
                        icon: Icons.directions_car_filled_rounded,
                        size: 52,
                        iconSize: 26,
                        borderRadius: 17,
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              widget.inspection.vehiclePlate,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),

                                const SizedBox(width: 4),

                                Expanded(
                                  child: AppText(
                                    widget.inspection.locationCity,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      AppStatusBadge(
                        label: 'AI',
                        color: AppTheme.infoColorFor(context),
                        backgroundColor: AppTheme.infoSoftFor(context),
                        compact: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                const AppText(
                  '1. Genel görünüm',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const AppText(
                  'Hasarın bulunduğu araç parçası ve çevresi aynı karede görünsün. İnsan ve plaka gibi kişisel bilgileri kadraja almayın.',
                ),
                const SizedBox(height: 12),
                _PhotoUploadArea(
                  key: const ValueKey('overview-photo'),
                  imageBytes: _overviewBytes,
                  isUploading: _isUploading,
                  onTap: () => _showImageSourceSheet(overview: true),
                ),
                if (_overviewBytes != null) ...[
                  const SizedBox(height: 12),
                  _SelectedFileInfo(
                    filename: _overviewFilename ?? 'Genel görünüm',
                    fileSize: _formatFileSize(_overviewBytes),
                    onChange: _isUploading
                        ? null
                        : () => _showImageSourceSheet(overview: true),
                  ),
                ],
                const SizedBox(height: 20),
                const AppText(
                  '2. Yakın detay',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const AppText(
                  'Aynı hasarın ayrıntılarını net gösterin; fotoğraf bulanık veya yansımalı olmasın.',
                ),
                const SizedBox(height: 12),
                _PhotoUploadArea(
                  key: const ValueKey('detail-photo'),
                  imageBytes: _selectedImageBytes,
                  isUploading: _isUploading,
                  onTap: _showImageSourceSheet,
                ),

                if (hasImage) ...[
                  const SizedBox(height: 12),

                  _SelectedFileInfo(
                    filename: _selectedFilename ?? 'Fotoğraf',
                    fileSize: _formatFileSize(),
                    onChange: _isUploading ? null : _showImageSourceSheet,
                  ),
                ],

                const SizedBox(height: 18),

                const _PhotoTipsCard(),

                const SizedBox(height: 18),

                const SizedBox(height: 26),

                const AppText('İki fotoğraf görsel değerlendirme için Google Gemini’ye gönderilir. İnsan, plaka veya belge gibi kişisel bilgileri kadraja almayın.'),
                const SizedBox(height: 12),

                PrimaryButton(
                  label: hasBothImages
                      ? 'Analizi Başlat'
                      : 'İki fotoğrafı tamamlayın',
                  icon: hasImage
                      ? Icons.auto_awesome_rounded
                      : Icons.add_a_photo_outlined,
                  isLoading: _isUploading,
                  onPressed: _isUploading || !hasBothImages
                      ? null
                      : _uploadImage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoUploadArea extends StatelessWidget {
  const _PhotoUploadArea({
    super.key,
    required this.imageBytes,
    required this.isUploading,
    required this.onTap,
  });

  final Uint8List? imageBytes;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    final hasImage = imageBytes != null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: isUploading ? null : onTap,

        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.medium),

          constraints: const BoxConstraints(minHeight: 280),
          height: hasImage ? 340 : null,

          width: double.infinity,

          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,

            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),

            border: Border.all(
              color: hasImage
                  ? colorScheme.primary.withValues(alpha: 0.55)
                  : colorScheme.outlineVariant,
              width: hasImage ? 1.5 : 1,
            ),
          ),

          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      imageBytes!,
                      fit: BoxFit.contain,
                      cacheWidth:
                          (MediaQuery.sizeOf(context).width *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round()
                              .clamp(600, 1600),
                      semanticLabel: 'Seçilen hasar fotoğrafı'.tr,
                    ),

                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.64),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 5),
                            AppText(
                              'Hazır',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIconBox(
                        icon: Icons.add_a_photo_outlined,
                        size: 82,
                        iconSize: 38,
                        borderRadius: 26,
                        backgroundColor: colorScheme.primaryContainer,
                      ),

                      const SizedBox(height: 20),

                      AppText(
                        'Fotoğraf ekleyin',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 7),

                      AppText(
                        'Kamera ile çekin veya galerinizden seçin',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingM),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: AppText(
                          'JPG • PNG • WEBP • Maks. 10 MB',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SelectedFileInfo extends StatelessWidget {
  const _SelectedFileInfo({
    required this.filename,
    required this.fileSize,
    required this.onChange,
  });

  final String filename;
  final String fileSize;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.image_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: AppText(
                  '$filename • $fileSize',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        TextButton.icon(
          onPressed: onChange,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const AppText('Değiştir'),
        ),
      ],
    );
  }
}

class _PhotoTipsCard extends StatelessWidget {
  const _PhotoTipsCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      showShadow: false,
      backgroundColor: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(18),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBox(
                icon: Icons.tips_and_updates_outlined,
                size: 38,
                iconSize: 20,
                borderRadius: 12,
                backgroundColor: AppTheme.infoSoftFor(context),
                iconColor: AppTheme.infoColorFor(context),
              ),

              SizedBox(width: 11),

              Expanded(
                child: AppText(
                  'Daha iyi sonuç için',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingM),

          const _PhotoTip(
            icon: Icons.wb_sunny_outlined,
            text: 'Fotoğrafı yeterli ışıkta ve net çekin.',
          ),

          const SizedBox(height: 10),

          const _PhotoTip(
            icon: Icons.center_focus_strong_outlined,
            text:
                'Genel görünüm ve yakın detay aynı araç bölgesini göstermeli.',
          ),

          const SizedBox(height: 10),

          const _PhotoTip(
            icon: Icons.zoom_out_map_rounded,
            text:
                'İki farklı fotoğraf kullanın. Yapay zekâ değerlendirmesi fiziksel ekspertiz yerine geçmez.',
          ),
        ],
      ),
    );
  }
}

class _PhotoTip extends StatelessWidget {
  const _PhotoTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),

        const SizedBox(width: 10),

        Expanded(
          child: AppText(
            text,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  const _ImageSourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),

        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppIconBox(icon: icon, size: 48, borderRadius: 15),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    AppText(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
