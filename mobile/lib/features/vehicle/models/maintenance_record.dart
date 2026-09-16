class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.maintenanceType,
    required this.maintenanceDate,
    required this.mileage,
    this.cost,
    this.note,
    this.nextRecommendedDate,
    this.nextRecommendedMileage,
    required this.createdByName,
  });
  final int id;
  final String maintenanceType;
  final DateTime maintenanceDate;
  final int mileage;
  final double? cost;
  final String? note;
  final DateTime? nextRecommendedDate;
  final int? nextRecommendedMileage;
  final String createdByName;

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) =>
      MaintenanceRecord(
        id: (json['id'] as num).toInt(),
        maintenanceType: json['maintenanceType'] as String? ?? 'CUSTOM',
        maintenanceDate: DateTime.parse(json['maintenanceDate'] as String),
        mileage: (json['mileage'] as num).toInt(),
        cost: (json['cost'] as num?)?.toDouble(),
        note: json['note'] as String?,
        nextRecommendedDate: DateTime.tryParse(
          json['nextRecommendedDate'] as String? ?? '',
        ),
        nextRecommendedMileage: (json['nextRecommendedMileage'] as num?)
            ?.toInt(),
        createdByName: json['createdByName'] as String? ?? '',
      );
}
