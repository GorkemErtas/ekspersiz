import * as ImagePicker from 'expo-image-picker';
import { Directory, File, Paths } from 'expo-file-system';
import { native } from './native';
import { api, session } from '../core/runtime';
import { inspections } from '../core/services';
import {
  registerProtectedCleanup,
  registerMediaCleanup,
} from '../core/protectedResources';

const protectedDirectory = () =>
  new Directory(Paths.cache, 'ekspersiz-protected');
const files = new Map<string, { uri: string; size: number }>();
let epoch = 0;
const listeners = new Set<() => void>();
export const imageEpoch = () => epoch;
export const subscribeImages = (listener: () => void) => {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
};
export function clearImages() {
  epoch++;
  files.clear();
  for (const directory of [
    protectedDirectory(),
    new Directory(Paths.cache, 'ekspersiz-images'),
  ]) {
    try {
      if (directory.exists) directory.delete();
    } catch {
      /* Old paths are never republished after epoch changes. */
    }
  }
  for (const listener of listeners) listener();
}
registerProtectedCleanup(clearImages);
// A previous process may have ended before its logout cleanup could run.
try {
  clearImages();
} catch {
  /* No old file is registered or exposed if native cache access is temporarily unavailable. */
}
registerMediaCleanup(() => {
  epoch++;
  files.clear();
  try {
    const directory = protectedDirectory();
    if (directory.exists) directory.delete();
  } catch {
    /* Paths remain unreachable after epoch invalidation. */
  }
  for (const listener of listeners) listener();
});
const remove = (uri: string) => {
  try {
    const file = new File(uri);
    if (file.exists) file.delete();
  } catch {
    /* Cache cleanup retries on the next session boundary. */
  }
};
export function removePrepared(uri: string) {
  if (uri.includes('/ekspersiz-images/prepared-')) remove(uri);
}
export async function pickPhoto(camera: boolean) {
  const { generation } = session.getSnapshot();
  // System photo selection grants access to the selected file; broad library access is unnecessary.
  if (camera && !(await ImagePicker.requestCameraPermissionsAsync()).granted)
    throw new Error(
      'Fotoğraf erişimine izin verin. İzni cihaz ayarlarından değiştirebilirsiniz.',
    );
  const result = await (
    camera ? ImagePicker.launchCameraAsync : ImagePicker.launchImageLibraryAsync
  )({
    mediaTypes: ['images'],
    allowsEditing: false,
    quality: 1,
    preferredAssetRepresentationMode:
      ImagePicker.UIImagePickerPreferredAssetRepresentationMode.Compatible,
    exif: false,
    base64: false,
  });
  session.check(generation);
  if (result.canceled) return null;
  const asset = result.assets[0];
  if (!asset) throw new Error('Fotoğraf seçilemedi.');
  let prepared: Awaited<ReturnType<ReturnType<typeof native>['prepareImage']>>;
  try {
    prepared = await native().prepareImage(asset.uri);
  } finally {
    if (
      asset.uri.startsWith(
        new Directory(Paths.cache, 'ImagePicker').uri.replace(/\/$/, '') + '/',
      )
    )
      remove(asset.uri);
  }
  try {
    session.check(generation);
    return prepared;
  } catch (error) {
    removePrepared(prepared.uri);
    throw error;
  }
}
/** Reauthorize every reuse. Disk paths include scope and are removed on transitions. */
export async function protectedImage(id: number, signal?: AbortSignal) {
  const snapshot = session.getSnapshot(),
    currentEpoch = epoch;
  const inspection = await inspections.get(id, signal);
  session.check(snapshot.generation);
  if (inspection.id !== id) throw new Error('İnceleme kimliği doğrulanamadı.');
  if (!inspection.imagePath) throw new Error('Fotoğraf bulunamadı.');
  const key = `${snapshot.profile?.id}-${snapshot.workspace}-${snapshot.generation}-${id}-${inspection.imagePath}`;
  const existing = files.get(key);
  if (existing && new File(existing.uri).exists) {
    files.delete(key);
    files.set(key, existing);
    return existing.uri;
  }
  const bytes = await api.request<ArrayBuffer>(`/inspections/${id}/image`, {
    binary: true,
    signal,
  });
  session.check(snapshot.generation);
  if (epoch !== currentEpoch) throw new Error('Fotoğraf oturumu değişti.');
  const directory = protectedDirectory();
  directory.create({ idempotent: true, intermediates: true });
  const file = new File(
    directory,
    `${snapshot.profile?.id}-${snapshot.workspace}-${snapshot.generation}-${id}.jpg`,
  );
  file.write(new Uint8Array(bytes));
  session.check(snapshot.generation);
  files.set(key, { uri: file.uri, size: bytes.byteLength });
  while (
    files.size > 6 ||
    [...files.values()].reduce((sum, item) => sum + item.size, 0) >
      12 * 1024 * 1024
  ) {
    const first = files.entries().next().value;
    if (!first) break;
    files.delete(first[0]);
    remove(first[1].uri);
  }
  return file.uri;
}
