export interface OtaUpdateSettings {
  projectId: string;
  channel: 'staging' | 'production';
  runtimeVersion: { policy: 'fingerprint' };
  updates: {
    enabled: true;
    url: string;
    requestHeaders: { 'expo-channel-name': string };
    checkAutomatically: 'ON_LOAD';
    fallbackToCacheTimeout: 0;
    useEmbeddedUpdate: true;
    disableAntiBrickingMeasures: false;
  };
}
export function otaUpdateConfig(
  env: NodeJS.ProcessEnv,
  options: { production: boolean; isInstalled?: () => boolean },
): OtaUpdateSettings | null;
