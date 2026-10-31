import { fireEvent, render, screen } from '@testing-library/react-native';
import MainShell from './MainShell';

const mockPush = jest.fn();
jest.mock('expo-router', () => ({
  useLocalSearchParams: () => ({}),
  useRouter: () => ({ push: mockPush }),
  useFocusEffect: jest.fn(),
}));
jest.mock('./WorkspaceSwitcher', () => () => null);
jest.mock('./HomeScreen', () => {
  const React = jest.requireActual<typeof import('react')>('react');
  const { TextInput, View } =
    jest.requireActual<typeof import('react-native')>('react-native');
  return function HomeFixture() {
    const [note, setNote] = React.useState('');
    return (
      <View>
        <TextInput
          accessibilityLabel="Korunan dashboard alanı"
          value={note}
          onChangeText={setNote}
        />
      </View>
    );
  };
});
jest.mock('../vehicle/VehicleListScreen', () => () => null);
jest.mock('../inspection/HistoryScreen', () => () => null);
jest.mock('../profile/ProfileScreen', () => () => null);

beforeEach(() => jest.clearAllMocks());
test('assistant remains an accessible immediate navigation action', async () => {
  await render(<MainShell />);
  await fireEvent.press(
    screen.getByRole('button', { name: 'AI Asistan’ı aç' }),
  );
  expect(mockPush).toHaveBeenCalledWith('/assistant');
});
test('tabs hide the home-only assistant and preserve visited screen state', async () => {
  await render(<MainShell />);
  await fireEvent.changeText(
    screen.getByLabelText('Korunan dashboard alanı'),
    'koru',
  );
  await fireEvent.press(screen.getByRole('tab', { name: 'Araçlar' }));
  expect(screen.queryByRole('button', { name: 'AI Asistan’ı aç' })).toBeNull();
  expect(
    screen.getByRole('tab', { name: 'Araçlar' }).props.accessibilityState
      .selected,
  ).toBe(true);
  await fireEvent.press(screen.getByRole('tab', { name: 'Ana Sayfa' }));
  expect(screen.getByLabelText('Korunan dashboard alanı').props.value).toBe(
    'koru',
  );
  expect(screen.getByRole('button', { name: 'AI Asistan’ı aç' })).toBeTruthy();
});
