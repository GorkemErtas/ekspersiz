class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.subscriptionPlan,
  });

  final int id;
  final String fullName;
  final String email;
  final String role;
  final String subscriptionPlan;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'USER',
      subscriptionPlan: json['subscriptionPlan'] as String? ?? 'FREE',
    );
  }
}
