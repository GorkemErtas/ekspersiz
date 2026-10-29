import { requireNativeModule } from 'expo-modules-core';
export interface NativeBridge {
  installationCompleted(): Promise<boolean>;
  completeInstallation(): Promise<void>;
  deviceId(): Promise<string>;
  integrityToken(project: string, hash: string): Promise<string>;
  prepareImage(uri: string): Promise<{
    uri: string;
    width: number;
    height: number;
    size: number;
    hash: string;
  }>;
  playUpdateInfo(): Promise<{
    available: boolean;
    immediateAllowed: boolean;
    inProgress: boolean;
  }>;
  immediateUpdate(): Promise<boolean>;
}
export default requireNativeModule<NativeBridge>('EkspersizNative');
