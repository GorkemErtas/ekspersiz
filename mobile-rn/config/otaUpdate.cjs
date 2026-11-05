'use strict';
const { easProject } = require('./productionEnvironment.cjs');
function otaUpdateConfig(
  env,
  {
    production,
    isInstalled = () => {
      try {
        require.resolve('expo-updates/package.json');
        return true;
      } catch {
        return false;
      }
    },
  },
) {
  const enabled = env.EXPO_UPDATES_ENABLED?.trim() ?? '0';
  const projectId = env.EXPO_UPDATES_PROJECT_ID?.trim();
  const channel = env.EXPO_UPDATES_CHANNEL?.trim();
  if (enabled === '0') {
    if (projectId || channel)
      throw new Error('OTA project/channel requires EXPO_UPDATES_ENABLED=1.');
    return null;
  }
  if (enabled !== '1') throw new Error('EXPO_UPDATES_ENABLED must be 0 or 1.');
  if (!production)
    throw new Error(
      'OTA requires the production Android identity and environment.',
    );
  if (!projectId || projectId !== easProject.id)
    throw new Error(
      'EXPO_UPDATES_PROJECT_ID must match the existing registered Expo project UUID.',
    );
  if (!['staging', 'production'].includes(channel))
    throw new Error('EXPO_UPDATES_CHANNEL must be staging or production.');
  if (env.EAS_BUILD_CHANNEL && env.EAS_BUILD_CHANNEL !== channel)
    throw new Error('EAS build channel and embedded update channel differ.');
  if (!isInstalled())
    throw new Error(
      'Install expo-updates and commit the lockfile before enabling OTA.',
    );
  return {
    projectId,
    channel,
    runtimeVersion: { policy: 'fingerprint' },
    updates: {
      enabled: true,
      url: `https://u.expo.dev/${projectId}`,
      requestHeaders: { 'expo-channel-name': channel },
      checkAutomatically: 'ON_LOAD',
      fallbackToCacheTimeout: 0,
      useEmbeddedUpdate: true,
      disableAntiBrickingMeasures: false,
    },
  };
}
module.exports = { otaUpdateConfig };
