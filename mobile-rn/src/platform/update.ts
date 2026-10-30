import { Linking, Platform } from 'react-native';
import {
  applicationId,
  nativeApplicationVersion,
  nativeBuildVersion,
} from 'expo-application';
import { api } from '../core/runtime';
import { native } from './native';
export interface UpdateStatus {
  required: boolean;
  immediate: boolean;
}
async function playUpdateInfo() {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      native().playUpdateInfo(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(
          () => reject(new Error('Mağaza yanıt vermedi.')),
          5000,
        );
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
export async function checkUpdate(): Promise<UpdateStatus> {
  if (Platform.OS !== 'android') return { required: false, immediate: false };
  // Independent policy and Play checks share the startup deadline, rather than
  // adding two five-second waits when a network/store service is unavailable.
  const [backend, play] = await Promise.allSettled([
    api.request<{ minimumAndroidBuild: number }>('/app/version', {
      auth: false,
      timeout: 5000,
    }),
    playUpdateInfo(),
  ]);
  const backendRequired =
    backend.status === 'fulfilled' &&
    Number.isFinite(backend.value.minimumAndroidBuild) &&
    Number(nativeBuildVersion) < backend.value.minimumAndroidBuild;
  if (play.status === 'fulfilled') {
    const update = play.value;
    return {
      required: backendRequired || update.available || update.inProgress,
      immediate: update.immediateAllowed || update.inProgress,
    };
  }
  return { required: backendRequired, immediate: false };
}
export async function performUpdate(status: UpdateStatus) {
  if (status.immediate) {
    try {
      if (await native().immediateUpdate()) return;
    } catch {
      /* Store is the supported fallback. */
    }
  }
  await Linking.openURL(
    `https://play.google.com/store/apps/details?id=${encodeURIComponent(applicationId ?? 'com.gorkem.ekspersiz')}`,
  );
}
export const appVersion = () =>
  `${nativeApplicationVersion ?? '1.0.0'} (${nativeBuildVersion ?? '52'})`;
