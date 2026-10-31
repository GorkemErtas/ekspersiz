import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, BackHandler, StyleSheet, View } from 'react-native';
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
import { BootReadyContext } from '../src/core/BootContext';
import Guide from '../src/features/onboarding/Guide';
import { native } from '../src/platform/native';
import { clearUnownedPushToken } from '../src/platform/push';
import {
  checkUpdate,
  performUpdate,
  type UpdateStatus,
} from '../src/platform/update';

export default function RootLayout() {
  const [loaded, error] = useFonts({
    InterRegular: require('../assets/fonts/Inter-Regular.ttf'),
    InterMedium: require('../assets/fonts/Inter-Medium.ttf'),
    FlutterMaterialIcons: require('../assets/fonts/MaterialIcons-Regular.otf'),
  });
  useEffect(() => {
    void clearUnownedPushToken().catch(() => undefined);
  }, []);
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
  const [boot, setBoot] = useState<'loading' | 'guide' | 'update'>('loading'),
    [update, setUpdate] = useState<UpdateStatus>({
      required: false,
      immediate: false,
    });
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
      })
      .finally(() => {
        // Includes an expired restored JWT; do not leave an inherited token owned
        // by the previous Flutter account while showing the login screen.
        if (!session.getSnapshot().token)
          void clearUnownedPushToken().catch(() => undefined);
      });
  }, []);
  const begin = useCallback(() => {
    void (async () => {
      const status = await checkUpdate();
      setUpdate(status);
      if (status.required) {
        setBoot('update');
        return;
      }
      if (!(await native().installationCompleted())) {
        setBoot('guide');
        return;
      }
      restore();
    })().catch((reason) =>
      setError(
        reason instanceof Error ? reason.message : 'Uygulama başlatılamadı.',
      ),
    );
  }, [restore]);
  useEffect(begin, [begin]);
  useEffect(() => {
    if (boot !== 'update') return;
    const listener = BackHandler.addEventListener(
      'hardwareBackPress',
      () => true,
    );
    return () => listener.remove();
  }, [boot]);
  return (
    <>
      <StatusBar style={mode === 'dark' ? 'light' : 'dark'} />
      <View
        style={styles.flex}
        accessibilityElementsHidden={!restored}
        importantForAccessibility={restored ? 'auto' : 'no-hide-descendants'}
      >
        <BootReadyContext.Provider value={restored}>
          <Stack
            screenOptions={{
              headerShown: false,
              contentStyle: { backgroundColor: 'transparent' },
              animation: 'fade_from_bottom',
            }}
          >
            <Stack.Screen name="index" />
            <Stack.Protected guard={restored && !state.profile}>
              <Stack.Screen name="login" />
              <Stack.Screen name="register" />
              <Stack.Screen name="forgot-password" />
              <Stack.Screen name="verify-email" />
            </Stack.Protected>
            <Stack.Protected guard={restored && !!state.profile}>
              <Stack.Screen name="(app)" />
              <Stack.Screen name="account" />
              <Stack.Screen name="change-password" />
            </Stack.Protected>
          </Stack>
        </BootReadyContext.Provider>
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
            padding: boot === 'guide' ? 0 : 22,
            gap: 22,
          }}
        >
          {boot === 'guide' ? (
            <Guide
              onFinish={() => {
                setBoot('loading');
                void native()
                  .completeInstallation()
                  .then(restore)
                  .catch((reason) =>
                    setError(
                      reason instanceof Error
                        ? reason.message
                        : 'Tercihiniz kaydedilemedi.',
                    ),
                  );
              }}
            />
          ) : boot === 'update' ? (
            <>
              <AppText variant="headlineSmall">Güncelleme Gerekli</AppText>
              <AppText>
                EksperSiz’in bu sürümü artık desteklenmiyor. Devam etmek için
                uygulamayı güncelleyin.
              </AppText>
              <Button
                label="Güncelle"
                onPress={() =>
                  void performUpdate(update)
                    .then(begin)
                    .catch(() =>
                      setError('Mağaza açılamadı. Bağlantınızı kontrol edin.'),
                    )
                }
              />
              {error && <AppText accessibilityRole="alert">{error}</AppText>}
            </>
          ) : error ? (
            <>
              <AppText accessibilityRole="alert">{error}</AppText>
              <Button
                label="Tekrar Dene"
                onPress={() => {
                  setError('');
                  begin();
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
