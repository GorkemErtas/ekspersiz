import { useEffect, useRef } from 'react';
import { AppState } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { useSession } from '../../src/core/runtime';
import { refreshProfile } from '../../src/core/services';
import { invalidate } from '../../src/core/queries';
import { registerDevice, watchPush } from '../../src/platform/push';
import { billing } from '../../src/features/billing/store';
import '../../src/platform/images';
import '../../src/features/inspection/analysisJobs';
export default function ProtectedLayout() {
  const { generation } = useSession(),
    router = useRouter();
  const previousGeneration = useRef(generation);
  useEffect(() => {
    if (previousGeneration.current !== generation) {
      previousGeneration.current = generation;
      router.replace('/main');
    }
  }, [generation, router]);
  useEffect(() => {
    void registerDevice().catch(() => undefined);
    const dispose = watchPush(() => {
      void invalidate('notifications', 'notifications/unread');
      router.push('/notifications');
    });
    const listener = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        void refreshProfile().catch(() => undefined);
        void registerDevice().catch(() => undefined);
        void invalidate(
          'notifications',
          'credits',
          'vehicles',
          'inspection',
          'assistant/entitlement',
          'business/members',
        );
        if (!billing.isBusy) void invalidate('billing/store');
      }
    });
    return () => {
      dispose();
      listener.remove();
    };
  }, [generation, router]);
  return (
    <Stack
      key={generation}
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: 'transparent' },
        animation: 'slide_from_right',
      }}
    >
      <Stack.Screen name="main" />
    </Stack>
  );
}

export { default as ErrorBoundary } from '../../src/design/RouteErrorBoundary';
