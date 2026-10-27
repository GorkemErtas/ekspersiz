class BusinessAccount {
  const BusinessAccount({
    required this.id,
    required this.companyName,
    required this.role,
    this.sandbox = false,
  });

  final int id;
  final String companyName;
  final String role;
  final bool sandbox;

  bool get isOwner => role == 'OWNER';

  String get roleLabel => isOwner ? 'Şirket sahibi' : 'Şirket üyesi';

  factory BusinessAccount.fromJson(Map<String, dynamic> json) {
    return BusinessAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      companyName: json['companyName'] as String? ?? '',
      role: json['role'] as String? ?? 'MEMBER',
      sandbox: json['sandbox'] as bool? ?? false,
    );
  }
}
