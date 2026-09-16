class BillingPlan {
  const BillingPlan({
    required this.plan,
    required this.title,
    required this.description,
    required this.fallbackMonthlyPrice,
    required this.currency,
    required this.highlighted,
    required this.features,
    this.productId,
    this.packageIdentifier,
  });

  final String plan;
  final String title;
  final String description;
  final String? productId;
  final String? packageIdentifier;
  final double fallbackMonthlyPrice;
  final String currency;
  final bool highlighted;
  final List<String> features;

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    return BillingPlan(
      plan: json['plan'] as String? ?? 'FREE',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      productId: json['productId'] as String?,
      packageIdentifier: json['packageIdentifier'] as String?,
      fallbackMonthlyPrice:
          (json['fallbackMonthlyPrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'TRY',
      highlighted: json['highlighted'] as bool? ?? false,
      features: (json['features'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}
