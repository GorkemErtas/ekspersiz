class DamageDetection {
  const DamageDetection({
    required this.id,
    required this.label,
    required this.confidence,
    required this.affectedPart,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final int id;
  final String label;
  final double confidence;
  final String affectedPart;

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  factory DamageDetection.fromJson(Map<String, dynamic> json) {
    return DamageDetection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      affectedPart: json['affectedPart'] as String? ?? 'UNKNOWN',
      x1: (json['x1'] as num?)?.toDouble() ?? 0,
      y1: (json['y1'] as num?)?.toDouble() ?? 0,
      x2: (json['x2'] as num?)?.toDouble() ?? 0,
      y2: (json['y2'] as num?)?.toDouble() ?? 0,
    );
  }
}
