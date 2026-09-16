class VehicleHistoryItem {
  const VehicleHistoryItem({
    required this.type,
    required this.title,
    required this.description,
    required this.occurredAt,
  });
  final String type;
  final String title;
  final String description;
  final DateTime occurredAt;
  factory VehicleHistoryItem.fromJson(Map<String, dynamic> json) =>
      VehicleHistoryItem(
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        occurredAt: DateTime.parse(json['occurredAt'] as String),
      );
}
