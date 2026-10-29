import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { Pressable, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from './components';
import { useTheme } from './ThemeProvider';

const SnackbarContext = createContext<(message: string) => void>(
  () => undefined,
);
export const useSnackbar = () => useContext(SnackbarContext);
export function SnackbarProvider({ children }: { children: ReactNode }) {
  const [message, setMessage] = useState('');
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const { mode } = useTheme();
  const insets = useSafeAreaInsets();
  useEffect(() => () => clearTimeout(timer.current), []);
  const show = (value: string) => {
    clearTimeout(timer.current);
    setMessage(value);
    timer.current = setTimeout(() => setMessage(''), 6000);
  };
  return (
    <SnackbarContext.Provider value={show}>
      {children}
      {message ? (
        <View
          style={{
            position: 'absolute',
            bottom: Math.max(insets.bottom, 12),
            left: 12,
            right: 12,
          }}
        >
          <Pressable
            accessibilityRole="alert"
            accessibilityLiveRegion="polite"
            accessibilityLabel={message}
            onPress={() => setMessage('')}
            style={{
              borderRadius: 12,
              padding: 16,
              backgroundColor: mode === 'dark' ? '#E6E1E5' : '#322F35',
            }}
          >
            <AppText style={{ color: mode === 'dark' ? '#322F35' : '#F5EFF7' }}>
              {message}
            </AppText>
          </Pressable>
        </View>
      ) : null}
    </SnackbarContext.Provider>
  );
}
