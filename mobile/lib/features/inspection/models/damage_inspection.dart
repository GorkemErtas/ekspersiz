import 'damage_detection.dart';
import 'damage_repair_recommendation.dart';
import 'inspection_report.dart';

class DamageInspection {
  const DamageInspection({
    required this.id,
    required this.vehicleId,
    required this.vehiclePlate,
    required this.userId,
    required this.imagePath,
    required this.status,
    required this.reportStatus,
    required this.reportMessage,
    required this.damageSeverity,
    required this.damageTypes,
    required this.affectedParts,
    required this.repairRecommendations,
    required this.confidenceScore,
    required this.analysisMessage,
    required this.createdAt,
    required this.completedAt,
    required this.detections,
    required this.report,
    required this.locationCity,
    required this.locationLatitude,
    required this.locationLongitude,
  });

  final int id;

  final int vehicleId;
  final String vehiclePlate;
  final int userId;

  final String? imagePath;

  final String status;

  final String? reportStatus;
  final String? reportMessage;

  final String? damageSeverity;

  final List<String> damageTypes;
  final List<String> affectedParts;

  final List<DamageRepairRecommendation> repairRecommendations;

  final double? confidenceScore;
  final String? analysisMessage;

  final DateTime? createdAt;
  final DateTime? completedAt;

  final List<DamageDetection> detections;

  final InspectionReport? report;

  final String locationCity;

  final double? locationLatitude;
  final double? locationLongitude;

  bool get isPending => status == 'PENDING';

  bool get isProcessing => status == 'PROCESSING';

  bool get isCompleted => status == 'COMPLETED';

  bool get isFailed => status == 'FAILED';

  bool get isReportPending => reportStatus == 'PENDING';

  bool get isReportProcessing => reportStatus == 'PROCESSING';

  bool get isReportCompleted => reportStatus == 'COMPLETED';

  bool get isReportFailed => reportStatus == 'FAILED';

  factory DamageInspection.fromJson(Map<String, dynamic> json) {
    final reportJson = json['report'];

    return DamageInspection(
      id: _parseInt(json['id']),
      vehicleId: _parseInt(json['vehicleId']),
      vehiclePlate: _parseString(json['vehiclePlate']),
      userId: _parseInt(json['userId']),
      imagePath: _parseNullableString(json['imagePath']),
      status: _parseEnumString(json['status'], fallback: 'PENDING'),
      reportStatus: _parseNullableEnumString(json['reportStatus']),
      reportMessage: _parseNullableString(json['reportMessage']),
      damageSeverity: _parseNullableEnumString(json['damageSeverity']),
      damageTypes: _parseStringList(json['damageTypes']),
      affectedParts: _parseStringList(json['affectedParts']),
      repairRecommendations: _parseRepairRecommendations(
        json['repairRecommendations'],
      ),
      confidenceScore: _parseNullableDouble(json['confidenceScore']),
      analysisMessage: _parseNullableString(json['analysisMessage']),
      createdAt: _parseDateTime(json['createdAt']),
      completedAt: _parseDateTime(json['completedAt']),
      detections: _parseDetections(json['detections']),
      report: reportJson is Map
          ? InspectionReport.fromJson(Map<String, dynamic>.from(reportJson))
          : null,
      locationCity: _parseString(json['locationCity']),
      locationLatitude: _parseNullableDouble(json['locationLatitude']),
      locationLongitude: _parseNullableDouble(json['locationLongitude']),
    );
  }

  static int _parseInt(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  static double? _parseNullableDouble(dynamic value) {
    return value is num ? value.toDouble() : null;
  }

  static String _parseString(dynamic value) {
    if (value is! String) {
      return '';
    }

    return value.trim();
  }

  static String? _parseNullableString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  static String _parseEnumString(dynamic value, {required String fallback}) {
    if (value is! String) {
      return fallback;
    }

    final normalized = value.trim().toUpperCase();

    return normalized.isEmpty ? fallback : normalized;
  }

  static String? _parseNullableEnumString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim().toUpperCase();

    return normalized.isEmpty ? null : normalized;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<String>()
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<DamageRepairRecommendation> _parseRepairRecommendations(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => DamageRepairRecommendation.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static List<DamageDetection> _parseDetections(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => DamageDetection.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
