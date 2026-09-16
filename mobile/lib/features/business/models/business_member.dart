class BusinessMember {
  const BusinessMember({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final int id;
  final int userId;
  final String fullName;
  final String email;
  final String role;

  factory BusinessMember.fromJson(Map<String, dynamic> json) {
    return BusinessMember(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}
