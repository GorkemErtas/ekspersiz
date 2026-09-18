class AnalysisQuota {
  const AnalysisQuota({
    required this.plan,
    required this.used,
    required this.limit,
    required this.remaining,
  });

  final String plan;
  final int used;
  final int limit;
  final int remaining;

  factory AnalysisQuota.fromJson(Map<String, dynamic> json) => AnalysisQuota(
    plan: json['plan'] as String? ?? 'FREE',
    used: (json['used'] as num?)?.toInt() ?? 0,
    limit: (json['limit'] as num?)?.toInt() ?? 0,
    remaining: (json['remaining'] as num?)?.toInt() ?? 0,
  );
}
