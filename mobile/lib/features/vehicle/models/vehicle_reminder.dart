class VehicleReminder {
  const VehicleReminder({
    required this.id,
    required this.reminderType,
    this.title,
    this.dueDate,
    this.dueMileage,
    this.note,
    required this.status,
    this.daysRemaining,
    this.mileageRemaining,
    this.sourceDate,
    this.sourceMileage,
    this.intervalMonths,
    this.intervalMileage,
    this.firstInspection,
  });
  final int id;
  final String reminderType;
  final String? title;
  final DateTime? dueDate;
  final int? dueMileage;
  final String? note;
  final String status;
  final int? daysRemaining;
  final int? mileageRemaining;
  final DateTime? sourceDate;
  final int? sourceMileage;
  final int? intervalMonths;
  final int? intervalMileage;
  final bool? firstInspection;

  factory VehicleReminder.fromJson(Map<String, dynamic> json) =>
      VehicleReminder(
        id: (json['id'] as num).toInt(),
        reminderType: json['reminderType'] as String? ?? 'CUSTOM',
        title: json['title'] as String?,
        dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
        dueMileage: (json['dueMileage'] as num?)?.toInt(),
        note: json['note'] as String?,
        status: json['status'] as String? ?? 'UPCOMING',
        daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
        mileageRemaining: (json['mileageRemaining'] as num?)?.toInt(),
        sourceDate: DateTime.tryParse(json['sourceDate'] as String? ?? ''),
        sourceMileage: (json['sourceMileage'] as num?)?.toInt(),
        intervalMonths: (json['intervalMonths'] as num?)?.toInt(),
        intervalMileage: (json['intervalMileage'] as num?)?.toInt(),
        firstInspection: json['firstInspection'] as bool?,
      );
}
