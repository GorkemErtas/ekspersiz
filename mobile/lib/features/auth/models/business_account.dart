import '../../../core/workspace/business_workspace_access.dart';

class BusinessAccount {
  const BusinessAccount({
    required this.id,
    required this.companyName,
    required this.role,
    this.sandbox = false,
    this.workspaceAvailable = false,
    this.workspaceAccessStatus = 'UNKNOWN',
  });

  final int id;
  final String companyName;
  final String role;
  final bool sandbox;
  final bool workspaceAvailable;
  final String workspaceAccessStatus;

  String get workspaceAccessMessage =>
      businessWorkspaceAccessMessage(workspaceAccessStatus);

  bool get isOwner => role == 'OWNER';

  String get roleLabel => isOwner ? 'Şirket sahibi' : 'Şirket üyesi';

  factory BusinessAccount.fromJson(Map<String, dynamic> json) {
    return BusinessAccount(
      id: (json['id'] as num?)?.toInt() ?? 0,
      companyName: json['companyName'] as String? ?? '',
      role: json['role'] as String? ?? 'MEMBER',
      sandbox: json['sandbox'] as bool? ?? false,
      workspaceAvailable:
          json['workspaceAvailable'] == true &&
          json['workspaceAccessStatus'] == 'ACTIVE',
      workspaceAccessStatus:
          json['workspaceAccessStatus'] as String? ?? 'UNKNOWN',
    );
  }
}
