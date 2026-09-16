class BillingStatus {
  const BillingStatus({
    required this.billingCustomerId,
    required this.currentPlan,
    required this.status,
    required this.autoRenewing,
    required this.sandbox,
    this.productId,
    this.currentPeriodEndsAt,
    this.managementUrl,
    this.lastSyncedAt,
  });

  final String billingCustomerId;
  final String currentPlan;
  final String status;
  final String? productId;
  final bool autoRenewing;
  final bool sandbox;
  final DateTime? currentPeriodEndsAt;
  final String? managementUrl;
  final DateTime? lastSyncedAt;

  factory BillingStatus.fromJson(Map<String, dynamic> json) {
    return BillingStatus(
      billingCustomerId: json['billingCustomerId'] as String? ?? '',
      currentPlan: json['currentPlan'] as String? ?? 'FREE',
      status: json['status'] as String? ?? 'NONE',
      productId: json['productId'] as String?,
      autoRenewing: json['autoRenewing'] as bool? ?? false,
      sandbox: json['sandbox'] as bool? ?? false,
      currentPeriodEndsAt: _parseDate(json['currentPeriodEndsAt']),
      managementUrl: json['managementUrl'] as String?,
      lastSyncedAt: _parseDate(json['lastSyncedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}
