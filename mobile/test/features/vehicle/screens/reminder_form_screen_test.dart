import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/vehicle/models/vehicle.dart';
import 'package:mobile/features/vehicle/models/vehicle_reminder.dart';
import 'package:mobile/features/vehicle/screens/reminder_form_screen.dart';

void main() {
  const vehicle = Vehicle(
    id: 5,
    plate: '35ABC123',
    brand: 'Honda',
    model: 'Civic',
    modelYear: 2025,
    mileage: 50000,
    primaryVehicle: true,
  );

  testWidgets('periodic maintenance asks for source values and intervals', (
    tester,
  ) async {
    const reminder = VehicleReminder(
      id: 1,
      reminderType: 'PERIODIC_MAINTENANCE',
      status: 'UPCOMING',
      sourceMileage: 50000,
      intervalMonths: 12,
      intervalMileage: 10000,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ReminderFormScreen(vehicle: vehicle, reminder: reminder),
      ),
    );

    expect(find.text('Son bakım tarihi'), findsOneWidget);
    expect(find.text('Son bakım kilometresi'), findsOneWidget);
    expect(find.text('Bakım aralığı (ay)'), findsOneWidget);
    expect(find.text('Bakım aralığı (km)'), findsOneWidget);
    expect(find.text('Hedef tarih'), findsNothing);
  });

  testWidgets('insurance asks only for the policy expiry date', (tester) async {
    const reminder = VehicleReminder(
      id: 2,
      reminderType: 'TRAFFIC_INSURANCE',
      status: 'UPCOMING',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ReminderFormScreen(vehicle: vehicle, reminder: reminder),
      ),
    );

    expect(find.text('Poliçede yazan bitiş tarihi'), findsOneWidget);
    expect(find.text('Hedef kilometre'), findsNothing);
  });

  testWidgets('first inspection uses vehicle profile data', (tester) async {
    const reminder = VehicleReminder(
      id: 3,
      reminderType: 'VEHICLE_INSPECTION',
      status: 'UPCOMING',
      firstInspection: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ReminderFormScreen(vehicle: vehicle, reminder: reminder),
      ),
    );

    expect(
      find.text('İlk muayene tarihi otomatik hesaplanacak'),
      findsOneWidget,
    );
    expect(
      find.text('Araç kategorisi veya uygunluk belgesi tarihi eksik.'),
      findsOneWidget,
    );
    expect(find.text('Hedef kilometre'), findsNothing);
  });
}
