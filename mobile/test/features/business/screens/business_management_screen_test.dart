import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/models/business_account.dart';
import 'package:mobile/features/business/models/business_member.dart';
import 'package:mobile/features/business/screens/business_management_screen.dart';
import 'package:mobile/features/business/services/business_service.dart';

void main() {
  testWidgets('business owner can see member invitation form', (tester) async {
    final businessService = _FakeBusinessService();

    await tester.pumpWidget(
      MaterialApp(
        home: BusinessManagementScreen(
          subscriptionPlan: 'BUSINESS',
          businessAccount: const BusinessAccount(
            id: 1,
            companyName: 'ABC Ekspertiz',
            role: 'OWNER',
          ),
          businessService: businessService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC Ekspertiz'), findsWidgets);
    expect(find.text('Şirket sahibi'), findsWidgets);
    expect(find.text('Üye davet et'), findsOneWidget);
    expect(find.text('Daveti kabul et'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Ayşe Yılmaz'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('ayse@example.com'), findsOneWidget);
    expect(find.byTooltip('Üyelikten çıkar'), findsOneWidget);
  });

  testWidgets('business owner can remove an employee', (tester) async {
    final businessService = _FakeBusinessService();

    await tester.pumpWidget(
      MaterialApp(
        home: BusinessManagementScreen(
          subscriptionPlan: 'BUSINESS',
          businessAccount: const BusinessAccount(
            id: 1,
            companyName: 'ABC Ekspertiz',
            role: 'OWNER',
          ),
          businessService: businessService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('Üyelikten çıkar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Üyelikten çıkar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Üyelikten Çıkar'));
    await tester.pumpAndSettle();

    expect(businessService.removedMembershipId, 20);
    expect(find.text('Ayşe Yılmaz'), findsNothing);
  });

  testWidgets('personal user can accept an invitation without business plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BusinessManagementScreen(subscriptionPlan: 'FREE'),
      ),
    );

    expect(find.text('Daveti kabul et'), findsOneWidget);
    expect(find.text('Şirket Daveti'), findsOneWidget);
    expect(find.text('Şirket İşlemleri'), findsNothing);
    expect(
      find.text('Davet edilen üyelerin BUSINESS planına ihtiyacı yoktur.'),
      findsOneWidget,
    );
    expect(find.text('Şirket oluştur'), findsNothing);
  });
}

class _FakeBusinessService extends BusinessService {
  _FakeBusinessService();

  int? removedMembershipId;
  final List<BusinessMember> _employees = [
    const BusinessMember(
      id: 20,
      userId: 2,
      fullName: 'Ayşe Yılmaz',
      email: 'ayse@example.com',
      role: 'MEMBER',
    ),
  ];

  @override
  Future<List<BusinessMember>> getEmployees() async => List.of(_employees);

  @override
  Future<void> removeEmployee(int membershipId) async {
    removedMembershipId = membershipId;
    _employees.removeWhere((employee) => employee.id == membershipId);
  }
}
