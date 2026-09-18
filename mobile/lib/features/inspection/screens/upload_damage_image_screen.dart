import 'package:mobile/core/localization/app_text.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon_box.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/primary_button.dart';

import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'analyzing_screen.dart';

class UploadDamageImageScreen extends StatefulWidget {
  const UploadDamageImageScreen({super.key, required this.inspection});

  final DamageInspection inspection;

  @override
  State<UploadDamageImageScreen> createState() =>
      _UploadDamageImageScreenState();
}

class _UploadDamageImageScreenState extends State<UploadDamageImageScreen> {
  static const int _maxImageSizeBytes = 10 * 1024 * 1024;

  final ImagePicker _imagePicker = ImagePicker();

  final InspectionService _inspectionService = const InspectionService();

  Uint8List? _selectedImageBytes;

  String? _selectedContentType;
  String? _selectedFilename;

  bool _isUploading = false;
  String? _qualityIssue;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image == null || !mounted) {
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
        _selectedImageBytes = bytes;

        _selectedContentType = detectedContentType;

        _selectedFilename = correctedFilename;
        _qualityIssue = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Fotoğraf seçilemedi.');
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
    final imageBytes = _selectedImageBytes;

    final contentType = _selectedContentType;

    final filename = _selectedFilename;

    if (imageBytes == null || contentType == null || filename == null) {
      _showMessage('Lütfen önce bir fotoğraf seçin.');
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
      final updatedInspection = await _inspectionService.uploadImage(
        inspectionId: widget.inspection.id,
        imageBytes: imageBytes,
        filename: filename,
        contentType: contentType,
      );

      final quality = await _inspectionService.validateImageQuality(
        widget.inspection.id,
      );

      if (!mounted) {
        return;
      }

      if (!quality.suitable) {
        setState(() {
          _qualityIssue = quality.message;
        });
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AnalyzingScreen(inspection: updatedInspection),
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

  void _showImageSourceSheet() {
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

        return Padding(
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
                'Hasarlı bölgenin fotoğrafını nasıl eklemek istediğinizi seçin.',
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

                  _pickImage(ImageSource.camera);
                },
              ),

              const SizedBox(height: 10),

              _ImageSourceOption(
                icon: Icons.photo_library_outlined,
                title: 'Galeriden seç',
                subtitle: 'Mevcut bir fotoğraf kullanın',
                onTap: () {
                  Navigator.of(context).pop();

                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatFileSize() {
    final bytes = _selectedImageBytes;

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

    return Scaffold(
      appBar: AppBar(title: const AppText('Hasar Fotoğrafı')),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),

            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),

              children: [
                const AppPageHeader(
                  icon: Icons.image_search_rounded,
                  title: 'Hasarlı bölgeyi görüntüleyin',
                  subtitle:
                      'Hasarın net göründüğü tek bir fotoğraf yükleyin. '
                      'AI modeli fotoğrafı inceleyerek hasar tipini, '
                      'etkilenen parçaları ve hasar seviyesini belirleyecek.',
                  badge: 'YAPAY ZEKÂ GÖRÜNTÜ ANALİZİ',
                ),

                const SizedBox(height: 24),

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

                _PhotoUploadArea(
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

                if (_qualityIssue != null) ...[
                  const SizedBox(height: 12),
                  _ImageQualityIssueCard(message: _qualityIssue!),
                ],

                const SizedBox(height: 18),

                const _PhotoTipsCard(),

                const SizedBox(height: 26),

                PrimaryButton(
                  label: hasImage ? 'AI Analizini Başlat' : 'Fotoğraf Seç',
                  icon: hasImage
                      ? Icons.auto_awesome_rounded
                      : Icons.add_a_photo_outlined,
                  isLoading: _isUploading,
                  onPressed: _isUploading
                      ? null
                      : hasImage
                      ? _uploadImage
                      : _showImageSourceSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageQualityIssueCard extends StatelessWidget {
  const _ImageQualityIssueCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      showShadow: false,
      backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.camera_alt_outlined, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Fotoğrafı yeniden çekin',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                AppText(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoUploadArea extends StatelessWidget {
  const _PhotoUploadArea({
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
          duration: const Duration(milliseconds: 200),

          constraints: const BoxConstraints(minHeight: 300, maxHeight: 430),

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
                    Image.memory(imageBytes!, fit: BoxFit.cover),

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
                  padding: const EdgeInsets.all(28),
                  child: Column(
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
                        'Hasar fotoğrafı ekleyin',
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

                      const SizedBox(height: 16),

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

          const SizedBox(height: 16),

          const _PhotoTip(
            icon: Icons.wb_sunny_outlined,
            text: 'Fotoğrafı yeterli ışıkta çekin.',
          ),

          const SizedBox(height: 10),

          const _PhotoTip(
            icon: Icons.center_focus_strong_outlined,
            text: 'Hasarlı bölgenin tamamını kadraja alın.',
          ),

          const SizedBox(height: 10),

          const _PhotoTip(
            icon: Icons.zoom_out_map_rounded,
            text: 'Aşırı yakın veya bulanık görüntülerden kaçının.',
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
