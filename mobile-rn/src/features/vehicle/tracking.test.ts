import { trackingPayload } from './tracking';
test('inspection reminder retains first-inspection semantics and discards unrelated targets', () =>
  expect(
    trackingPayload(
      'reminders',
      {
        type: 'VEHICLE_INSPECTION',
        sourceDate: '2026-01-01',
        dueMileage: '1000',
        intervalMonths: '99',
      },
      true,
      false,
    ),
  ).toEqual({
    reminderType: 'VEHICLE_INSPECTION',
    sourceDate: '2026-01-01',
    firstInspection: true,
  }));
test('recurring maintenance derives targets on the server from its sources and intervals', () =>
  expect(
    trackingPayload(
      'reminders',
      {
        type: 'PERIODIC_MAINTENANCE',
        sourceDate: '2026-01-01',
        sourceMileage: '20000',
        intervalMonths: '12',
        intervalMileage: '15000',
        dueDate: '2030-01-01',
      },
      false,
      false,
    ),
  ).toEqual({
    reminderType: 'PERIODIC_MAINTENANCE',
    sourceDate: '2026-01-01',
    sourceMileage: 20000,
    intervalMonths: 12,
    intervalMileage: 15000,
  }));
test('insurance deadlines never carry a mileage target', () =>
  expect(
    trackingPayload(
      'reminders',
      {
        type: 'TRAFFIC_INSURANCE',
        dueDate: '2026-12-01',
        dueMileage: '100000',
      },
      false,
      true,
    ),
  ).toEqual({ reminderType: 'TRAFFIC_INSURANCE', dueDate: '2026-12-01' }));
test('custom reminder requires a title and a due target', () => {
  expect(() =>
    trackingPayload(
      'reminders',
      { type: 'CUSTOM', dueDate: '2026-01-01' },
      false,
      true,
    ),
  ).toThrow('Başlık');
  expect(() =>
    trackingPayload(
      'reminders',
      { type: 'CUSTOM', title: 'Kontrol' },
      false,
      true,
    ),
  ).toThrow('hedef');
});
test('mileage, intervals and monetary inputs reject invalid finite/integer values', () => {
  expect(() =>
    trackingPayload(
      'reminders',
      { type: 'TIRE_CHECK', dueMileage: 'Infinity' },
      false,
      true,
    ),
  ).toThrow();
  expect(() =>
    trackingPayload(
      'reminders',
      {
        type: 'PERIODIC_MAINTENANCE',
        sourceDate: '2026-01-01',
        intervalMonths: '0',
      },
      false,
      false,
    ),
  ).toThrow();
});
