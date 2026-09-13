class DamageRepairRecommendation {
  const DamageRepairRecommendation({
    required this.damageType,
    required this.recommendedAction,
    required this.partReplacementRequired,
    required this.affectedParts,
  });

  final String damageType;
  final String recommendedAction;
  final bool partReplacementRequired;
  final List<String> affectedParts;

  factory DamageRepairRecommendation.fromJson(Map<String, dynamic> json) {
    return DamageRepairRecommendation(
      damageType: json['damageType'] as String? ?? 'UNKNOWN',
      recommendedAction: json['recommendedAction'] as String? ?? 'NO_ACTION',
      partReplacementRequired:
          json['partReplacementRequired'] as bool? ?? false,
      affectedParts:
          (json['affectedParts'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }
}
