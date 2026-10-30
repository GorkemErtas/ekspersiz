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
  let backendRequired = false;
  try {
    const result = await api.request<{ minimumAndroidBuild: number }>(
      '/app/version',
      { auth: false, timeout: 5000 },
    );
    backendRequired =
      Number.isFinite(result.minimumAndroidBuild) &&
      Number(nativeBuildVersion) < result.minimumAndroidBuild;
  } catch {
    /* Same offline fallback as Flutter. */
  }
  try {
    const update = await playUpdateInfo();
    return {
      required: backendRequired || update.available || update.inProgress,
      immediate: update.immediateAllowed || update.inProgress,
    };
  } catch {
    return { required: backendRequired, immediate: false };
  }
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
