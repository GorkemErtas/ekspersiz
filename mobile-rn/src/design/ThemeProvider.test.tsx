import {
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react-native';
import { Appearance } from 'react-native';
import * as SecureStore from 'expo-secure-store';
import * as SystemUI from 'expo-system-ui';
import { ThemeProvider, useTheme } from './ThemeProvider';
import { AppText, Button } from './components';
import { palettes } from './tokens';

jest.mock('expo-system-ui', () => ({
  setBackgroundColorAsync: jest.fn(async () => undefined),
}));

function Controls() {
  const { mode, toggle } = useTheme();
  return (
    <>
      <AppText>{mode}</AppText>
      <Button label="Tema değiştir" onPress={toggle} />
    </>
  );
}

test('restored theme and theme changes reach native surfaces as well as app content', async () => {
  const appearance = jest
    .spyOn(Appearance, 'setColorScheme')
    .mockImplementation(() => undefined);
  jest.mocked(SecureStore.getItemAsync).mockResolvedValueOnce('light');
  try {
    await render(
      <ThemeProvider>
        <Controls />
      </ThemeProvider>,
    );
    await waitFor(() => expect(screen.getByText('light')).toBeTruthy());
    expect(appearance).toHaveBeenLastCalledWith('light');
    expect(SystemUI.setBackgroundColorAsync).toHaveBeenLastCalledWith(
      palettes.light.background,
    );
    await fireEvent.press(
      screen.getByRole('button', { name: 'Tema değiştir' }),
    );
    expect(screen.getByText('dark')).toBeTruthy();
    expect(appearance).toHaveBeenLastCalledWith('dark');
    expect(SystemUI.setBackgroundColorAsync).toHaveBeenLastCalledWith(
      palettes.dark.background,
    );
    expect(SecureStore.setItemAsync).toHaveBeenLastCalledWith(
      'preferred_theme',
      'dark',
    );
  } finally {
    appearance.mockRestore();
  }
});
