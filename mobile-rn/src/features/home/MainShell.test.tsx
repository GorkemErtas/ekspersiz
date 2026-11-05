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
  return function HomeFixture({ contentBottom }: { contentBottom: number }) {
    const [note, setNote] = React.useState('');
    return (
      <View
        testID="home-scroll-content"
        style={{ paddingBottom: contentBottom }}
      >
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

test('floating assistant leaves surrounding content touchable and updates scroll clearance after text scaling', async () => {
  await render(<MainShell />);
  const overlay = screen.getByTestId('assistant-overlay');
  expect(overlay.props.pointerEvents).toBe('box-none');
  expect(overlay).toHaveStyle({
    position: 'absolute',
    backgroundColor: 'transparent',
  });
  expect(screen.queryByTestId('assistant-dock')).toBeNull();

  await fireEvent(
    screen.getByRole('button', { name: 'AI Asistan’ı aç' }),
    'layout',
    {
      nativeEvent: { layout: { height: 80, width: 190, x: 0, y: 0 } },
    },
  );
  expect(screen.getByTestId('home-scroll-content')).toHaveStyle({
    paddingBottom: 104,
  });
  expect(screen.getByTestId('bottom-navigation')).toBeTruthy();
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
