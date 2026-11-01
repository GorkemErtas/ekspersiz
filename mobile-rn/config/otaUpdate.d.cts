export interface OtaUpdateSettings {
  projectId: string;
  channel: 'staging' | 'production';
  runtimeVersion: string;
  updates: {
    url: string;
    requestHeaders: { 'expo-channel-name': string };
    checkAutomatically: 'ON_LOAD';
    fallbackToCacheTimeout: 0;
  };
}
export function otaUpdateConfig(
  env: NodeJS.ProcessEnv,
  options: {production: boolean; versionName: string; isInstalled?: () => boolean},
): OtaUpdateSettings | null;
