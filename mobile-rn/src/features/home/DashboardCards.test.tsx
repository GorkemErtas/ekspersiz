import { fireEvent, render, screen } from '@testing-library/react-native';
import type { VehicleOverview } from '../../core/models';
import { AnalysisHero, PrimaryCard, TrackingPeek } from './DashboardCards';

const vehicle = {
  id: 1,
  plate: '34 TEST 123',
  brand: 'Mercedes-Benz',
  model: 'Uzun model adı',
  modelYear: 2024,
  mileage: 42000,
  primaryVehicle: true,
};
const overview: VehicleOverview = {
  vehicle,
  trackingStatus: 'GOOD',
  disclaimer: '',
  upcomingReminders: [],
};

test.each([
  ['ATTENTION', 'Dikkat gerekiyor'],
  ['DUE_SOON', 'Yaklaşan işlem var'],
  ['GOOD', 'Takibiniz güncel'],
  ['UNKNOWN', 'Takip durumu belirsiz'],
  ['', 'Takip durumu belirsiz'],
])(
  'tracking presents the server state %s without claiming unknown states are healthy',
  async (trackingStatus, title) => {
    const open = jest.fn();
    await render(
      <TrackingPeek
        overview={{ ...overview, trackingStatus }}
        onPress={open}
      />,
    );
    await fireEvent.press(
      screen.getByRole('button', { name: `Araç takibi, ${title}` }),
    );
    expect(open).toHaveBeenCalledTimes(1);
    expect(screen.getByText(title)).toBeTruthy();
    if (trackingStatus !== 'GOOD')
      expect(screen.queryByText('Takibiniz güncel')).toBeNull();
  },
);

test('reminders do not hide the warning state and further reminders remain discoverable', async () => {
  await render(
    <TrackingPeek
      overview={{
        ...overview,
        trackingStatus: 'ATTENTION',
        upcomingReminders: [
          {
            id: 1,
            reminderType: 'MAINTENANCE',
            title: 'Periyodik bakım',
            status: 'OVERDUE',
          },
          {
            id: 2,
            reminderType: 'INSPECTION',
            title: 'Araç muayenesi',
            status: 'DUE_SOON',
          },
          {
            id: 3,
            reminderType: 'INSURANCE',
            title: 'Sigorta',
            status: 'DUE_SOON',
          },
        ],
      }}
      onPress={jest.fn()}
    />,
  );
  expect(screen.getByText('Dikkat gerekiyor')).toBeTruthy();
  expect(screen.getByText('Periyodik bakım')).toBeTruthy();
  expect(screen.getByText('+1 hatırlatıcı daha')).toBeTruthy();
});

test('dashboard primary actions preserve their callbacks and full vehicle details', async () => {
  const analyze = jest.fn(),
    choose = jest.fn();
  await render(
    <>
      <AnalysisHero onPress={analyze} />
      <PrimaryCard vehicle={vehicle} onPress={choose} />
    </>,
  );
  await fireEvent.press(
    screen.getByRole('button', { name: 'Yeni Analiz Başlat' }),
  );
  await fireEvent.press(screen.getByRole('button', { name: 'Ana aracı seç' }));
  expect(analyze).toHaveBeenCalledTimes(1);
  expect(choose).toHaveBeenCalledTimes(1);
  expect(screen.getByText('34 TEST 123')).toBeTruthy();
  expect(screen.getByText('2024 · 42.000 km')).toBeTruthy();
});
