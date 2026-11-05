import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import * as SecureStore from 'expo-secure-store';
import { Appearance } from 'react-native';
import * as SystemUI from 'expo-system-ui';
import { palettes, type Palette, type ThemeMode } from './tokens';

const ThemeContext = createContext<{
  mode: ThemeMode;
  colors: Palette;
  toggle: () => void;
}>({
  mode: 'dark',
  colors: palettes.dark,
  toggle: () => undefined,
});
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [mode, setMode] = useState<ThemeMode>('dark');
  const [ready, setReady] = useState(false);
  useEffect(() => {
    void SecureStore.getItemAsync('preferred_theme')
      .then((saved) => {
        if (saved === 'light') setMode('light');
      })
      .catch(() => undefined)
      .finally(() => setReady(true));
  }, []);
  useEffect(() => {
    if (!ready) return;
    // Native dialogs and the window behind system bars share the saved theme.
    Appearance.setColorScheme(mode);
    void SystemUI.setBackgroundColorAsync(palettes[mode].background).catch(
      () => undefined,
    );
  }, [mode, ready]);
  const toggle = () => {
    const next = mode === 'dark' ? 'light' : 'dark';
    setMode(next);
    void SecureStore.setItemAsync('preferred_theme', next).catch(
      () => undefined,
    );
  };
  return (
    <ThemeContext.Provider value={{ mode, colors: palettes[mode], toggle }}>
      {ready ? children : null}
    </ThemeContext.Provider>
  );
}
export const useTheme = () => useContext(ThemeContext);
export const ThemeTestProvider = ThemeContext.Provider;
