import Constants from 'expo-constants';
import { Platform, PermissionsAndroid } from 'react-native';
import { api, session, queryClient } from '../core/runtime';

const firebaseConfigured = () =>
  Platform.OS === 'android'
    ? Constants.expoConfig?.extra?.androidFirebase === true
    : Constants.expoConfig?.extra?.iosFirebase === true;
const sdk = () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports -- Firebase is optional until real platform config is supplied.
  require('@react-native-firebase/messaging') as typeof import('@react-native-firebase/messaging');
let currentRegistration: { token: string; generation: number } | undefined;
let serial: Promise<void> = Promise.resolve();
let initialChecked = false;
let registrationEpoch = 0;
let stoppedGeneration: number | undefined;
export function registerBackgroundMessaging() {
  if (!firebaseConfigured()) return;
  try {
    const messaging = sdk();
    messaging.setBackgroundMessageHandler(
      messaging.getMessaging(),
      async () => {
        /* No protected data or user session is opened in a background isolate. */
      },
    );
  } catch {
    /* Configuration errors are surfaced when requesting authenticated registration. */
  }
}
export async function registerDevice(explicit = false) {
  if (!firebaseConfigured())
    throw new Error('Bildirim servisi şu anda kullanılamıyor.');
  const snapshot = session.getSnapshot();
  if (explicit) stoppedGeneration = undefined;
  if (stoppedGeneration === snapshot.generation) return;
  const epoch = registrationEpoch;
  if (!snapshot.profile || !snapshot.token) return;
  const module = sdk(),
    messaging = module.getMessaging();
  if (Platform.OS === 'android' && Number(Platform.Version) >= 33) {
    const permission = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
    );
    if (permission !== PermissionsAndroid.RESULTS.GRANTED)
      throw new Error(
        'Bildirim izni verilmedi. Cihaz ayarlarından izin verebilirsiniz.',
      );
  } else if (Platform.OS === 'ios') {
    const permission = await module.requestPermission(messaging, {
      provisional: true,
    });
    if (
      permission !== module.AuthorizationStatus.AUTHORIZED &&
      permission !== module.AuthorizationStatus.PROVISIONAL
    )
      throw new Error('Bildirim izni verilmedi.');
  }
  session.check(snapshot.generation);
  if (Platform.OS === 'ios') {
    if (!module.isDeviceRegisteredForRemoteMessages(messaging))
      await module.registerDeviceForRemoteMessages(messaging);
    let apns: string | null = null;
    for (let attempt = 0; attempt < 5 && !apns; attempt++) {
      session.check(snapshot.generation);
      if (epoch !== registrationEpoch) return;
      apns = await module.getAPNSToken(messaging);
      if (!apns && attempt < 4)
        await new Promise((resolve) => setTimeout(resolve, 500));
    }
    if (!apns)
      throw new Error(
        'Bildirim kaydı henüz tamamlanamadı. Lütfen yeniden deneyin.',
      );
  }
  const token = await module.getToken(messaging);
  session.check(snapshot.generation);
  if (
    !token ||
    (currentRegistration?.token === token &&
      currentRegistration.generation === snapshot.generation)
  )
    return;
  const next = serial.then(async () => {
    session.check(snapshot.generation);
    if (epoch !== registrationEpoch) return;
    if (
      currentRegistration?.token === token &&
      currentRegistration.generation === snapshot.generation
    )
      return;
    await api.request('/notifications/devices', {
      method: 'POST',
      timeout: 5000,
      body: { token, platform: Platform.OS === 'ios' ? 'IOS' : 'ANDROID' },
    });
    session.check(snapshot.generation);
    currentRegistration = { token, generation: snapshot.generation };
  });
  serial = next.catch(() => undefined);
  await next;
}
export async function unregisterDevice() {
  const generation = session.getSnapshot().generation;
  stoppedGeneration = generation;
  registrationEpoch++;
  const next = serial.then(async () => {
    if (session.getSnapshot().generation !== generation) return;
    const current = currentRegistration;
    if (!current || current.generation !== generation) return;
    currentRegistration = undefined;
    try {
      await api.request(
        `/notifications/devices?token=${encodeURIComponent(current.token)}`,
        { method: 'DELETE', timeout: 5000 },
      );
    } catch {
      /* Logout continues offline, matching Flutter. */
    }
  });
  serial = next.catch(() => undefined);
  await next;
}
export function watchPush(
  onOpen: (data: Record<string, string | object>) => void,
) {
  if (!firebaseConfigured()) return () => undefined;
  try {
    let active = true;
    const generation = session.getSnapshot().generation;
    const current = () =>
      active && session.getSnapshot().generation === generation;
    const module = sdk(),
      messaging = module.getMessaging();
    const refresh = module.onTokenRefresh(messaging, () => {
      if (!current()) return;
      currentRegistration = undefined;
      void registerDevice().catch(() => undefined);
    });
    const message = module.onMessage(messaging, () => {
      if (!current()) return;
      void queryClient.invalidateQueries({
        predicate: (q) => String(q.queryKey.at(-1)).startsWith('notifications'),
      });
    });
    const opened = module.onNotificationOpenedApp(messaging, (event) => {
      if (current() && event.data) onOpen(event.data);
    });
    if (!initialChecked) {
      initialChecked = true;
      void module
        .getInitialNotification(messaging)
        .then((event) => {
          if (current() && event?.data) onOpen(event.data);
        })
        .catch(() => undefined);
    }
    return () => {
      active = false;
      refresh();
      message();
      opened();
    };
  } catch {
    return () => undefined;
  }
}
