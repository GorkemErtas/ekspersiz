import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { QueryClientProvider } from '@tanstack/react-query';
import { useFonts } from 'expo-font';
import { queryClient, session, useSession } from '../src/core/runtime';
import { ThemeProvider, useTheme } from '../src/design/ThemeProvider';
import { StudioBackground } from '../src/design/StudioBackground';
import { SnackbarProvider } from '../src/design/Snackbar';
import { AppText, Button } from '../src/design/components';
import { restoreSession } from '../src/features/auth/auth';

export default function RootLayout() {
  const [loaded, error] = useFonts({
    InterRegular: require('../assets/fonts/Inter-Regular.ttf'),
    InterMedium: require('../assets/fonts/Inter-Medium.ttf'),
    FlutterMaterialIcons: require('../assets/fonts/MaterialIcons-Regular.otf'),
  });
  if (error) throw error;
  if (!loaded) return null;
  return (
    <SafeAreaProvider>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider>
          <View style={styles.flex}>
            <StudioBackground />
            <SnackbarProvider>
              <Navigation />
            </SnackbarProvider>
          </View>
        </ThemeProvider>
      </QueryClientProvider>
    </SafeAreaProvider>
  );
}

function Navigation() {
  const { mode, colors } = useTheme();
  const state = useSession();
  const [restored, setRestored] = useState(false),
    [error, setError] = useState('');
  const restore = useCallback(() => {
    void restoreSession()
      .then(() => setRestored(true))
      .catch((reason: unknown) => {
        // An unauthorized restore already cleared the session. Offline restore stays retryable.
        if (!session.getSnapshot().token) setRestored(true);
        else
          setError(
            reason instanceof Error ? reason.message : 'Oturum doğrulanamadı.',
          );
      });
  }, []);
  useEffect(restore, [restore]);
  return (
    <>
      <StatusBar style={mode === 'dark' ? 'light' : 'dark'} />
      <View
        style={styles.flex}
        accessibilityElementsHidden={!restored}
        importantForAccessibility={restored ? 'auto' : 'no-hide-descendants'}
      >
        <Stack
          screenOptions={{
            headerShown: false,
            contentStyle: { backgroundColor: 'transparent' },
            animation: 'fade_from_bottom',
          }}
        >
          <Stack.Screen name="index" />
          <Stack.Protected guard={!state.profile}>
            <Stack.Screen name="login" />
            <Stack.Screen name="register" />
            <Stack.Screen name="forgot-password" />
            <Stack.Screen name="verify-email" />
          </Stack.Protected>
          <Stack.Protected guard={!!state.profile}>
            <Stack.Screen name="account" />
            <Stack.Screen name="change-password" />
          </Stack.Protected>
        </Stack>
      </View>
      {!restored && (
        <View
          accessibilityViewIsModal
          style={{
            position: 'absolute',
            top: 0,
            right: 0,
            bottom: 0,
            left: 0,
            backgroundColor: colors.background,
            justifyContent: 'center',
            alignItems: 'center',
            padding: 22,
            gap: 22,
          }}
        >
          {error ? (
            <>
              <AppText accessibilityRole="alert">{error}</AppText>
              <Button
                label="Tekrar Dene"
                onPress={() => {
                  setError('');
                  restore();
                }}
              />
            </>
          ) : (
            <ActivityIndicator
              color={colors.primary}
              accessibilityLabel="Oturum doğrulanıyor"
            />
          )}
        </View>
      )}
    </>
  );
}
const styles = StyleSheet.create({ flex: { flex: 1 } });
