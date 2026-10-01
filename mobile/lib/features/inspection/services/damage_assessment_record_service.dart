import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/damage_assessment_record.dart';

class DamageAssessmentRecordService {
  const DamageAssessmentRecordService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;

  Future<DamageAssessmentRecord?> get(int inspectionId) async {
    try {
      final response =
          await apiClient.get('/inspections/$inspectionId/damage-record');
      return _parse(response);
    } on ApiException catch (exception) {
      if (exception.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<DamageAssessmentRecord> create({
    required int inspectionId,
    required DateTime incidentDateTime,
    required String incidentCity,
    String? incidentDistrict,
    String? incidentAddress,
    required String incidentDescription,
    required String declarantFullName,
  }) async {
    final response = await apiClient.post(
      '/inspections/$inspectionId/damage-record',
      body: _body(
        incidentDateTime: incidentDateTime,
        incidentCity: incidentCity,
        incidentDistrict: incidentDistrict,
        incidentAddress: incidentAddress,
        incidentDescription: incidentDescription,
        declarantFullName: declarantFullName,
      ),
    );
    return _parse(response);
  }

  Future<DamageAssessmentRecord> update({
    required int inspectionId,
    required DateTime incidentDateTime,
    required String incidentCity,
    String? incidentDistrict,
    String? incidentAddress,
    required String incidentDescription,
    required String declarantFullName,
  }) async {
    final response = await apiClient.put(
      '/inspections/$inspectionId/damage-record',
      body: _body(
        incidentDateTime: incidentDateTime,
        incidentCity: incidentCity,
        incidentDistrict: incidentDistrict,
        incidentAddress: incidentAddress,
        incidentDescription: incidentDescription,
        declarantFullName: declarantFullName,
      ),
    );
    return _parse(response);
  }

  Future<DamageAssessmentRecord> finalize(int inspectionId) async {
    final response = await apiClient.post(
      '/inspections/$inspectionId/damage-record/finalize',
    );
    return _parse(response);
  }

  Map<String, dynamic> _body({
    required DateTime incidentDateTime,
    required String incidentCity,
    String? incidentDistrict,
    String? incidentAddress,
    required String incidentDescription,
    required String declarantFullName,
  }) {
    return {
      'incidentDateTime': incidentDateTime.toIso8601String(),
      'incidentCity': incidentCity.trim(),
      'incidentDistrict': _nullable(incidentDistrict),
      'incidentAddress': _nullable(incidentAddress),
      'incidentDescription': incidentDescription.trim(),
      'declarantFullName': declarantFullName.trim(),
    };
  }

  String? _nullable(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  DamageAssessmentRecord _parse(dynamic response) {
    if (response is! Map) {
      throw const FormatException('Tutanak verisi geçersiz.');
    }
    return DamageAssessmentRecord.fromJson(Map<String, dynamic>.from(response));
  }
}
