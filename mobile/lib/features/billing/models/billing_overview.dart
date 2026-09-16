import 'billing_plan.dart';
import 'billing_status.dart';

class BillingOverview {
  const BillingOverview({required this.status, required this.plans});

  final BillingStatus status;
  final List<BillingPlan> plans;

  factory BillingOverview.fromJson(Map<String, dynamic> json) {
    final statusJson = json['status'];
    final plansJson = json['plans'];

    if (statusJson is! Map || plansJson is! List) {
      throw const FormatException('Abonelik bilgisi okunamadı.');
    }

    return BillingOverview(
      status: BillingStatus.fromJson(Map<String, dynamic>.from(statusJson)),
      plans: plansJson
          .whereType<Map>()
          .map((plan) => BillingPlan.fromJson(Map<String, dynamic>.from(plan)))
          .toList(growable: false),
    );
  }
}
