import { fireEvent, render, screen } from '@testing-library/react-native';
import VehicleFormScreen from './VehicleFormScreen';
import { modelYearItems } from './vehicleYears';
import { vehicles } from '../../core/services';
import { useResource } from '../../core/queries';
import type { Vehicle } from '../../core/models';

const mockBack = jest.fn();
let mockParams: { edit?: string } = {};
jest.mock('expo-router', () => ({
  useLocalSearchParams: () => mockParams,
  useRouter: () => ({ back: mockBack, canGoBack: () => true }),
}));
jest.mock('../../core/services', () => ({
  vehicles: { get: jest.fn(), save: jest.fn() },
}));
jest.mock('../../core/queries', () => ({
  useResource: jest.fn(),
  invalidate: jest.fn(async () => undefined),
}));

const vehicle: Vehicle = {
  id: 1,
  plate: '34ABC123',
  brand: 'Toyota',
  model: 'Corolla',
  modelYear: 2021,
  mileage: 45200,
  primaryVehicle: true,
  notes: '',
};
beforeEach(() => {
  jest.clearAllMocks();
  mockParams = {};
  jest.mocked(vehicles.save).mockResolvedValue(vehicle);
  jest
    .mocked(useResource)
    .mockReturnValue({ data: undefined, isPending: false } as ReturnType<
      typeof useResource
    >);
});

test('years follow the calendar, descend through 1950, and explicitly retain legacy years', () => {
  const items = modelYearItems(undefined, 2031);
  expect(items.slice(0, 3).map((item) => item.value)).toEqual([
    '2031',
    '2030',
    '2029',
  ]);
  expect(items.at(-1)?.value).toBe('1950');
  expect(items).toHaveLength(82);
  expect(modelYearItems()[0]?.value).toBe(String(new Date().getFullYear()));
  expect(modelYearItems(1942).at(-1)).toEqual({
    value: '1942',
    title: '1942 (kayıtlı değer)',
  });
});

test('a searchable year selection survives field edits and is sent as a number on create', async () => {
  await render(<VehicleFormScreen />);
  await fireEvent.press(screen.getByRole('button', { name: 'Model yılı' }));
  await fireEvent.changeText(screen.getByLabelText('Seçeneklerde ara'), '2024');
  await fireEvent.press(screen.getByRole('button', { name: '2024' }));
  await fireEvent.changeText(screen.getByLabelText('Plaka'), '34NEW12');
  for (const [name, value] of [
    ['Marka', 'Toyota'],
    ['Model', 'Corolla'],
  ]) {
    await fireEvent.press(screen.getByRole('button', { name: name }));
    if (screen.queryByLabelText('Seçeneklerde ara'))
      await fireEvent.changeText(
        screen.getByLabelText('Seçeneklerde ara'),
        value!,
      );
    await fireEvent.press(screen.getByRole('button', { name: value }));
  }
  expect(
    screen.getByRole('button', { name: 'Model yılı' }).props.accessibilityValue
      .text,
  ).toBe('2024');
  await fireEvent.press(screen.getByRole('button', { name: 'Kaydet' }));
  expect(vehicles.save).toHaveBeenCalledWith(
    expect.objectContaining({ plate: '34NEW12', modelYear: 2024, mileage: 0 }),
    undefined,
  );
  expect(mockBack).toHaveBeenCalledTimes(1);
});

test.each([1942, new Date().getFullYear() + 5])(
  'editing retains existing out-of-range year %i without coercion',
  async (modelYear) => {
    mockParams = { edit: '1' };
    jest.mocked(useResource).mockReturnValue({
      data: { ...vehicle, modelYear },
      isPending: false,
    } as ReturnType<typeof useResource>);
    await render(<VehicleFormScreen />);
    expect(
      screen.getByRole('button', { name: 'Model yılı' }).props
        .accessibilityValue.text,
    ).toBe(modelYear + ' (kayıtlı değer)');
    await fireEvent.changeText(
      screen.getByLabelText('Notlar'),
      'Güncel bakım notu',
    );
    await fireEvent.press(screen.getByRole('button', { name: 'Kaydet' }));
    expect(vehicles.save).toHaveBeenCalledWith(
      expect.objectContaining({ modelYear, notes: 'Güncel bakım notu' }),
      1,
    );
  },
);

test('existing mileage validation still blocks invalid edits', async () => {
  mockParams = { edit: '1' };
  jest
    .mocked(useResource)
    .mockReturnValue({ data: vehicle, isPending: false } as ReturnType<
      typeof useResource
    >);
  await render(<VehicleFormScreen />);
  await fireEvent.changeText(screen.getByLabelText('Kilometre'), '2000001');
  await fireEvent.press(screen.getByRole('button', { name: 'Kaydet' }));
  expect(vehicles.save).not.toHaveBeenCalled();
});
