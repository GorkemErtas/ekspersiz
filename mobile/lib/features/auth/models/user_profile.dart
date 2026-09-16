import 'business_account.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.subscriptionPlan,
    this.businessAccount,
  });

  final int id;
  final String fullName;
  final String email;
  final String subscriptionPlan;
  final BusinessAccount? businessAccount;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      subscriptionPlan: json['subscriptionPlan'] as String? ?? 'FREE',
      businessAccount: json['businessAccount'] is Map
          ? BusinessAccount.fromJson(
              Map<String, dynamic>.from(json['businessAccount'] as Map),
            )
          : null,
    );
  }
}
