import '../../../core/network/api_client.dart';
import '../models/damage_inspection.dart';

class InspectionService {
  const InspectionService({
    this.apiClient = const ApiClient(),
  });

  static const Duration _analysisTimeout = Duration(
    seconds: 90,
  );

  final ApiClient apiClient;

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

    return _parseInspection(
      response,
      'Hasar incelemesi oluşturulamadı.',
    );
  }

  Future<List<DamageInspection>>
  getInspections() async {
    final response = await apiClient.get(
      '/inspections',
    );

    if (response is! List) {
      throw const FormatException(
        'Hasar incelemeleri alınamadı.',
      );
    }

    return response.map(
          (item) {
        if (item is! Map) {
          throw const FormatException(
            'Hasar incelemesi verisi geçersiz.',
          );
        }

        return DamageInspection.fromJson(
          Map<String, dynamic>.from(item),
        );
      },
    ).toList();
  }

  Future<DamageInspection> getInspectionById(
      int inspectionId,
      ) async {
    final response = await apiClient.get(
      '/inspections/$inspectionId',
    );

    return _parseInspection(
      response,
      'Hasar incelemesi alınamadı.',
    );
  }

  Future<DamageInspection> uploadImage({
    required int inspectionId,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
  }) async {
    final response = await apiClient.postMultipart(
      '/inspections/$inspectionId/image',
      fileBytes: imageBytes,
      filename: filename,
      fileFieldName: 'image',
      contentType: contentType,
    );

    return _parseInspection(
      response,
      'Hasar fotoğrafı yüklenemedi.',
    );
  }

  Future<DamageInspection> analyzeInspection(
      int inspectionId,
      ) async {
    final response = await apiClient.post(
      '/inspections/$inspectionId/analyze',
      timeout: _analysisTimeout,
    );

    return _parseInspection(
      response,
      'Hasar analizi tamamlanamadı.',
    );
  }

  Future<DamageInspection> regenerateReport(
      int inspectionId,
      ) async {
    final response = await apiClient.post(
      '/inspections/$inspectionId/report',
      timeout: _analysisTimeout,
    );

    return _parseInspection(
      response,
      'AI raporu yeniden oluşturulamadı.',
    );
  }

  DamageInspection _parseInspection(
      dynamic response,
      String errorMessage,
      ) {
    if (response is! Map) {
      throw FormatException(
        errorMessage,
      );
    }

    return DamageInspection.fromJson(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }
}