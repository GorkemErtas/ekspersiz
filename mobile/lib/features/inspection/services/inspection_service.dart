import 'dart:typed_data';

import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_client.dart';
import '../models/damage_inspection.dart';
import '../models/image_quality_result.dart';
import 'inspection_image_cache.dart';

class InspectionService {
  const InspectionService({
    this.apiClient = const ApiClient(),
    this.imageCache,
  });

  static const Duration _analysisTimeout = Duration(seconds: 90);

  final ApiClient apiClient;
  final InspectionImageCache? imageCache;

  InspectionImageCache get images =>
      imageCache ?? InspectionImageCache.instance;

  Future<DamageInspection> createInspection({
    required int vehicleId,
    required String city,
    required double latitude,
    required double longitude,
  }) async {
    final normalizedCity = city.trim();

    final response = await apiClient.post(
      '/inspections'
      '?vehicleId=$vehicleId'
      '&city=${Uri.encodeQueryComponent(normalizedCity)}'
      '&latitude=${Uri.encodeQueryComponent(latitude.toString())}'
      '&longitude=${Uri.encodeQueryComponent(longitude.toString())}',
    );

    return _parseInspection(response, 'Hasar incelemesi oluşturulamadı.');
  }

  Future<List<DamageInspection>> getInspections() async {
    final response = await apiClient.get('/inspections');

    if (response is! List) {
      throw const FormatException('Hasar incelemeleri alınamadı.');
    }

    return response.map((item) {
      if (item is! Map) {
        throw const FormatException('Hasar incelemesi verisi geçersiz.');
      }

      return DamageInspection.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<DamageInspection> getInspectionById(int inspectionId) async {
    final response = await apiClient.get('/inspections/$inspectionId');

    return _parseInspection(response, 'Hasar incelemesi alınamadı.');
  }

  Future<DamageInspection> uploadImage({
    required int inspectionId,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  }) async {
    images.invalidate(inspectionId);
    final scope = SessionManager.imageScope.value;
    final epoch = images.epoch;
    final response = await apiClient.postMultipart(
      '/inspections/$inspectionId/image',
      fileBytes: imageBytes,
      filename: filename,
      fileFieldName: 'image',
      contentType: contentType,
    );

    final uploaded = _parseInspection(response, 'Hasar fotoğrafı yüklenemedi.');
    if (uploaded.id == inspectionId &&
        uploaded.imagePath != null &&
        imageBytes is Uint8List) {
      await images.seed(
        scope: scope,
        epoch: epoch,
        inspectionId: inspectionId,
        imagePath: uploaded.imagePath!,
        bytes: imageBytes,
      );
    }
    return uploaded;
  }

  Future<DamageInspection> analyzeInspection(
    int inspectionId, {
    required String vehicleRegion,
  }) async {
    final normalizedRegion = vehicleRegion.trim().toUpperCase();
    if (normalizedRegion != 'FRONT' && normalizedRegion != 'REAR') {
      throw const FormatException('Araç bölgesi seçimi geçersiz.');
    }

    final response = await apiClient.post(
      '/inspections/$inspectionId/analyze'
      '?vehicleRegion=${Uri.encodeQueryComponent(normalizedRegion)}',
      timeout: _analysisTimeout,
    );

    return _parseInspection(response, 'Hasar analizi tamamlanamadı.');
  }

  Future<Uint8List> getInspectionImage(
    int inspectionId, {
    bool forceRefresh = false,
  }) {
    return images.load(
      inspectionId: inspectionId,
      forceRefresh: forceRefresh,
      authorize: () async {
        final current = await getInspectionById(inspectionId);
        if (current.id != inspectionId) {
          throw const FormatException('İnceleme kimliği geçersiz.');
        }
        return current.imagePath;
      },
      download: () => apiClient.getBytes('/inspections/$inspectionId/image'),
    );
  }

  Future<ImageQualityResult> validateImageQuality(int inspectionId) async {
    final response = await apiClient.post(
      '/inspections/$inspectionId/image-quality',
      timeout: _analysisTimeout,
    );
    if (response is! Map) {
      throw const FormatException(
        'Fotoğraf uygunluk sonucu geçerli formatta alınamadı.',
      );
    }
    return ImageQualityResult.fromJson(Map<String, dynamic>.from(response));
  }

  Future<DamageInspection> regenerateReport(int inspectionId) async {
    final response = await apiClient.post(
      '/inspections/$inspectionId/report',
      timeout: _analysisTimeout,
    );

    return _parseInspection(response, 'AI raporu yeniden oluşturulamadı.');
  }

  DamageInspection _parseInspection(dynamic response, String errorMessage) {
    if (response is! Map) {
      throw FormatException(errorMessage);
    }

    return DamageInspection.fromJson(Map<String, dynamic>.from(response));
  }
}
