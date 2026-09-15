class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.subscriptionPlan,
  });

  final int id;
  final String fullName;
  final String email;
  final String subscriptionPlan;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      subscriptionPlan: json['subscriptionPlan'] as String? ?? 'FREE',
    );
  }
}
