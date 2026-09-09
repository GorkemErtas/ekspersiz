import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/damage_inspection.dart';
import '../services/inspection_service.dart';
import 'analyzing_screen.dart';

class UploadDamageImageScreen extends StatefulWidget {
  const UploadDamageImageScreen({
    super.key,
    required this.inspection,
  });

  final DamageInspection inspection;

  @override
  State<UploadDamageImageScreen> createState() =>
      _UploadDamageImageScreenState();
}

class _UploadDamageImageScreenState
    extends State<UploadDamageImageScreen> {
  static const int _maxImageSizeBytes =
      10 * 1024 * 1024;

  static const Set<String> _supportedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  final ImagePicker _imagePicker = ImagePicker();

  final InspectionService _inspectionService =
  const InspectionService();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  bool _isUploading = false;

  Future<void> _pickImage(
      ImageSource source,
      ) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image == null || !mounted) {
        return;
      }

      final extension = _getExtension(
        image.name,
      );

      if (!_supportedExtensions.contains(extension)) {
        _showMessage(
          'Sadece JPG, JPEG, PNG veya WEBP '
              'formatındaki fotoğraflar destekleniyor.',
        );
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        _showMessage(
          'Seçilen fotoğraf boş veya okunamıyor.',
        );
        return;
      }

      if (bytes.length > _maxImageSizeBytes) {
        _showMessage(
          'Fotoğraf boyutu 10 MB’dan büyük olamaz.',
        );
        return;
      }

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Fotoğraf seçilemedi.',
      );
    }
  }

  String _getExtension(
      String filename,
      ) {
    final parts = filename.split('.');

    if (parts.length < 2) {
      return '';
    }

    return parts.last.toLowerCase();
  }

  String? _getContentType(
      String filename,
      ) {
    final extension = _getExtension(
      filename,
    );

    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpeg' || 'jpg' => 'image/jpeg',
      _ => null,
    };
  }

  Future<void> _uploadImage() async {
    final image = _selectedImage;
    final imageBytes = _selectedImageBytes;

    if (image == null || imageBytes == null) {
      _showMessage(
        'Lütfen önce bir fotoğraf seçin.',
      );
      return;
    }

    if (imageBytes.isEmpty) {
      _showMessage(
        'Seçilen fotoğraf boş veya okunamıyor.',
      );
      return;
    }

    if (imageBytes.length > _maxImageSizeBytes) {
      _showMessage(
        'Fotoğraf boyutu 10 MB’dan büyük olamaz.',
      );
      return;
    }

    final contentType = _getContentType(
      image.name,
    );

    if (contentType == null) {
      _showMessage(
        'Bu fotoğraf formatı desteklenmiyor.',
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final updatedInspection =
      await _inspectionService.uploadImage(
        inspectionId: widget.inspection.id,
        imageBytes: imageBytes,
        filename: image.name,
        contentType: contentType,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AnalyzingScreen(
            inspection: updatedInspection,
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

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showImageSourceSheet() {
    if (_isUploading) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  title: const Text(
                    'Kamera ile çek',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();

                    _pickImage(
                      ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text(
                    'Galeriden seç',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();

                    _pickImage(
                      ImageSource.gallery,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hasar Fotoğrafı',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 760,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                28,
              ),
              children: [
                Text(
                  'Hasarlı bölgeyi ekleyin',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hasarın net göründüğü bir fotoğraf seçin. '
                      'Çok karanlık veya aşırı yakın görüntüler '
                      'analiz doğruluğunu düşürebilir. '
                      'Maksimum dosya boyutu 10 MB’dır.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                AppCard(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hasar İncelemesi',
                        style:
                        textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                          colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.inspection.vehiclePlate} '
                            '• '
                            '${widget.inspection.locationCity}',
                        style:
                        textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                GestureDetector(
                  onTap: _isUploading
                      ? null
                      : _showImageSourceSheet,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 280,
                      maxHeight: 420,
                    ),
                    decoration: BoxDecoration(
                      color:
                      colorScheme.surfaceContainerLow,
                      borderRadius:
                      BorderRadius.circular(22),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedImageBytes == null
                        ? Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: colorScheme
                                .primaryContainer,
                            borderRadius:
                            BorderRadius.circular(
                              22,
                            ),
                          ),
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            color: colorScheme.primary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Fotoğraf eklemek için dokunun',
                          style: TextStyle(
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kamera veya galeri',
                          style: TextStyle(
                            color: colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                        : Image.memory(
                      _selectedImageBytes!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                if (_selectedImage != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : _showImageSourceSheet,
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                    label: const Text(
                      'Fotoğrafı Değiştir',
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                PrimaryButton(
                  label: 'Fotoğrafı Yükle',
                  icon: Icons.cloud_upload_outlined,
                  isLoading: _isUploading,
                  onPressed: _isUploading
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