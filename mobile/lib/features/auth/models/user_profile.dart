class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.accountType,
    required this.subscriptionPlan,
  });

  final int id;
  final String fullName;
  final String email;
  final String accountType;
  final String subscriptionPlan;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      accountType: json['accountType'] as String? ?? 'INDIVIDUAL',
      subscriptionPlan: json['subscriptionPlan'] as String? ?? 'FREE',
    );
  }
}