class InspectionReport {
  const InspectionReport({
    required this.title,
    required this.summary,
    required this.damageDescription,
    required this.repairRecommendation,
    required this.estimatedMinimumPrice,
    required this.estimatedMaximumPrice,
    required this.currency,
    required this.priceInformation,
    required this.priceSourceDescription,
    required this.disclaimer,
    required this.generatedAt,
  });

  final String title;
  final String summary;
  final String damageDescription;
  final String repairRecommendation;

  final double estimatedMinimumPrice;
  final double estimatedMaximumPrice;

  final String currency;

  final String priceInformation;
  final String priceSourceDescription;
  final String disclaimer;

  final DateTime? generatedAt;

  factory InspectionReport.fromJson(Map<String, dynamic> json) {
    return InspectionReport(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      damageDescription: json['damageDescription'] as String? ?? '',
      repairRecommendation: json['repairRecommendation'] as String? ?? '',
      estimatedMinimumPrice:
          (json['estimatedMinimumPrice'] as num?)?.toDouble() ?? 0,
      estimatedMaximumPrice:
          (json['estimatedMaximumPrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'TRY',
      priceInformation: json['priceInformation'] as String? ?? '',
      priceSourceDescription: json['priceSourceDescription'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? ''),
    );
  }
}
