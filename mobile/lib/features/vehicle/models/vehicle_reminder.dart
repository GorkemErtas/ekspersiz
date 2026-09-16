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
      );
}
