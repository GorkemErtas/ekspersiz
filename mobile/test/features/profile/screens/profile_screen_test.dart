import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/models/business_account.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';

void main() {
  for (final entry in {
    'FREE': 'Ücretsiz',
    'PLUS': 'Plus',
    'PRO': 'Pro',
    'BUSINESS': 'Kurumsal',
  }.entries) {
    testWidgets('profile shows user identity and ${entry.key} subscription', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            fullName: 'Test User',
            email: 'user@example.com',
            subscriptionPlan: entry.key,
          ),
        ),
      );

      expect(find.text('Test User'), findsWidgets);
      expect(find.text(entry.value), findsWidgets);
      expect(find.text('Bireysel'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Abonelik Planı'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('Abonelik Planı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('member profile hides business management action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          fullName: 'Test User',
          email: 'user@example.com',
          subscriptionPlan: 'PLUS',
          businessAccount: BusinessAccount(
            id: 12,
            companyName: 'ABC Ekspertiz',
            role: 'MEMBER',
          ),
        ),
      ),
    );

    expect(find.text('Plus'), findsWidgets);
    expect(find.text('Şirket üyesi'), findsWidgets);

    expect(find.text('ABC Ekspertiz'), findsOneWidget);
    expect(find.text('Şirket İşlemleri'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'personal non-business profile hides business operations and shows invitation action',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(
            fullName: 'Free User',
            email: 'free@example.com',
            subscriptionPlan: 'FREE',
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Şirket Daveti'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Şirket Daveti'), findsOneWidget);
      expect(find.text('Şirket İşlemleri'), findsNothing);
    },
  );

  testWidgets('business plan profile shows business operations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          fullName: 'Business User',
          email: 'business@example.com',
          subscriptionPlan: 'BUSINESS',
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Şirket İşlemleri'),
      150,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Şirket İşlemleri'), findsOneWidget);
    expect(find.text('Şirket Daveti'), findsNothing);
  });

  testWidgets('owner profile shows business management action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          fullName: 'Owner User',
          email: 'owner@example.com',
          subscriptionPlan: 'BUSINESS',
          businessAccount: BusinessAccount(
            id: 12,
            companyName: 'ABC Ekspertiz',
            role: 'OWNER',
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Şirket İşlemleri'),
      150,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Şirket İşlemleri'), findsOneWidget);
  });
}
