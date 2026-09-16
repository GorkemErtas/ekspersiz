class AppNotification {
  const AppNotification({
    required this.id,
    this.vehicleId,
    required this.notificationType,
    required this.severity,
    required this.title,
    required this.body,
    this.navigationTarget,
    required this.read,
    required this.createdAt,
  });

  final int id;
  final int? vehicleId;
  final String notificationType;
  final String severity;
  final String title;
  final String body;
  final String? navigationTarget;
  final bool read;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        vehicleId: (json['vehicleId'] as num?)?.toInt(),
        notificationType: json['notificationType'] as String? ?? '',
        severity: json['severity'] as String? ?? 'INFO',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        navigationTarget: json['navigationTarget'] as String?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
