import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/models/auth_response.dart';
import 'package:mobile/features/auth/models/user_profile.dart';

void main() {
  for (final plan in ['FREE', 'PLUS', 'PRO', 'BUSINESS']) {
    test('login and session restoration preserve the same user for $plan', () {
      final auth = AuthResponse.fromJson({
        'accessToken': 'test-token',
        'tokenType': 'Bearer',
        'expiresIn': 86400000,
        'userId': 7,
        'fullName': 'Test User',
        'email': 'user@example.com',
        'subscriptionPlan': plan,
      });
      final profile = UserProfile.fromJson({
        'id': 7,
        'fullName': 'Test User',
        'email': 'user@example.com',
        'subscriptionPlan': plan,
        'subscriptionStartedAt': null,
        'subscriptionExpiresAt': null,
      });

      expect(auth.accessToken, 'test-token');
      expect(auth.tokenType, 'Bearer');
      expect(auth.expiresIn, 86400000);
      expect(auth.userId, 7);
      expect(profile.id, auth.userId);
      expect(profile.fullName, auth.fullName);
      expect(profile.email, auth.email);
      expect(auth.subscriptionPlan, plan);
      expect(profile.subscriptionPlan, plan);
      expect(auth.businessAccount, isNull);
      expect(profile.businessAccount, isNull);
    });
  }

  test('login and session restoration preserve business membership', () {
    const businessAccount = {
      'id': 12,
      'companyName': 'ABC Ekspertiz',
      'role': 'MEMBER',
    };
    final auth = AuthResponse.fromJson({
      'accessToken': 'test-token',
      'tokenType': 'Bearer',
      'expiresIn': 86400000,
      'userId': 7,
      'fullName': 'Test User',
      'email': 'user@example.com',
      'subscriptionPlan': 'PLUS',
      'businessAccount': businessAccount,
    });
    final profile = UserProfile.fromJson({
      'id': 7,
      'fullName': 'Test User',
      'email': 'user@example.com',
      'subscriptionPlan': 'PLUS',
      'subscriptionStartedAt': null,
      'subscriptionExpiresAt': null,
      'businessAccount': businessAccount,
    });

    expect(auth.businessAccount?.id, 12);
    expect(auth.businessAccount?.companyName, 'ABC Ekspertiz');
    expect(auth.businessAccount?.role, 'MEMBER');
    expect(auth.businessAccount?.isOwner, isFalse);
    expect(profile.businessAccount?.companyName, 'ABC Ekspertiz');
    expect(profile.subscriptionPlan, 'PLUS');
  });
}
