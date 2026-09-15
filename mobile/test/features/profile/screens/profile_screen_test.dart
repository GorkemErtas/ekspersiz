import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';

void main() {
  for (final entry in {
    'FREE': 'Free',
    'PLUS': 'Plus',
    'PRO': 'Pro',
    'BUSINESS': 'Business',
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
      expect(find.text('Kurumsal'), findsNothing);

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
}
