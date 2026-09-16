import 'business_account.dart';

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.subscriptionPlan,
    this.businessAccount,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final int userId;
  final String fullName;
  final String email;
  final String subscriptionPlan;
  final BusinessAccount? businessAccount;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
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
