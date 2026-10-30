import { Linking, Platform } from 'react-native';
import { nativeApplicationVersion, nativeBuildVersion } from 'expo-application';
import { api } from '../core/runtime';
import { native } from './native';
export interface UpdateStatus {
  required: boolean;
  immediate: boolean;
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
    const update = await native().playUpdateInfo();
    return {
      required: backendRequired || update.available || update.inProgress,
      immediate: update.immediateAllowed,
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
    'https://play.google.com/store/apps/details?id=com.gorkem.ekspersiz',
  );
}
export const appVersion = () =>
  `${nativeApplicationVersion ?? '1.0.0'} (${nativeBuildVersion ?? '52'})`;
