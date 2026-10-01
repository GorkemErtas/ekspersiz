class DamageAssessmentRecord {
  const DamageAssessmentRecord({
    required this.id,
    required this.inspectionId,
    required this.recordNumber,
    required this.status,
    required this.documentVersion,
    required this.incidentDateTime,
    required this.incidentCity,
    required this.incidentDistrict,
    required this.incidentAddress,
    required this.incidentDescription,
    required this.declarantFullName,
    required this.createdAt,
    required this.updatedAt,
    required this.finalizedAt,
  });

  final int id;
  final int inspectionId;
  final String recordNumber;
  final String status;
  final int documentVersion;
  final DateTime incidentDateTime;
  final String incidentCity;
  final String? incidentDistrict;
  final String? incidentAddress;
  final String incidentDescription;
  final String declarantFullName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? finalizedAt;

  bool get isDraft => status == 'DRAFT';
  bool get isFinalized => status == 'FINALIZED';

  factory DamageAssessmentRecord.fromJson(Map<String, dynamic> json) {
    return DamageAssessmentRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      inspectionId: (json['inspectionId'] as num?)?.toInt() ?? 0,
      recordNumber: _string(json['recordNumber']),
      status: _string(json['status']).toUpperCase(),
      documentVersion: (json['documentVersion'] as num?)?.toInt() ?? 1,
      incidentDateTime: DateTime.parse(_string(json['incidentDateTime'])),
      incidentCity: _string(json['incidentCity']),
      incidentDistrict: _nullableString(json['incidentDistrict']),
      incidentAddress: _nullableString(json['incidentAddress']),
      incidentDescription: _string(json['incidentDescription']),
      declarantFullName: _string(json['declarantFullName']),
      createdAt: _dateTime(json['createdAt']),
      updatedAt: _dateTime(json['updatedAt']),
      finalizedAt: _dateTime(json['finalizedAt']),
    );
  }

  static String _string(dynamic value) =>
      value is String ? value.trim() : '';

  static String? _nullableString(dynamic value) {
    final result = _string(value);
    return result.isEmpty ? null : result;
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
