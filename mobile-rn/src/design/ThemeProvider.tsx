import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import * as SecureStore from 'expo-secure-store';
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
