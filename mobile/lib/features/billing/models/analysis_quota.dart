class AnalysisQuota {
  const AnalysisQuota({
    required this.plan,
    required this.used,
    required this.baseLimit,
    required this.rewardedClaimed,
    required this.rewardedEligible,
    required this.totalLimit,
    required this.remaining,
  });

  final String plan;
  final int used;
  final int baseLimit;
  final bool rewardedClaimed;
  final bool rewardedEligible;
  final int totalLimit;
  final int remaining;

  factory AnalysisQuota.fromJson(Map<String, dynamic> json) => AnalysisQuota(
    plan: json['plan'] as String? ?? 'FREE',
    used: (json['used'] as num?)?.toInt() ?? 0,
    baseLimit: (json['baseLimit'] as num?)?.toInt() ?? 0,
    rewardedClaimed: json['rewardedClaimed'] as bool? ?? false,
    rewardedEligible: json['rewardedEligible'] as bool? ?? false,
    totalLimit: (json['totalLimit'] as num?)?.toInt() ?? 0,
    remaining: (json['remaining'] as num?)?.toInt() ?? 0,
  );
}
