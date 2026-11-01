'use strict';
// OTA remains disabled until an Expo project is linked and native expo-updates is installed.
function otaUpdateConfig(env, { production, versionName, isInstalled = () => {
  try { require.resolve('expo-updates/package.json'); return true; }
  catch { return false; }
} }) {
  const enabled = env.EXPO_UPDATES_ENABLED?.trim() ?? '';
  const projectId = env.EXPO_UPDATES_PROJECT_ID?.trim() ?? '';
  const channel = env.EXPO_UPDATES_CHANNEL?.trim() ?? '';
  if (!enabled || enabled === '0') {
    if (projectId || channel) throw new Error('OTA project/channel requires EXPO_UPDATES_ENABLED=1.');
    return null;
  }
  if (enabled !== '1') throw new Error('EXPO_UPDATES_ENABLED must be 0 or 1.');
  if (!production) throw new Error('OTA requires an explicitly signed production Android build.');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(projectId))
    throw new Error('EXPO_UPDATES_PROJECT_ID must be a valid UUID.');
  if (channel !== 'production' && channel !== 'staging')
    throw new Error('EXPO_UPDATES_CHANNEL must be staging or production.');
  if (!/^\d+\.\d+\.\d+$/.test(versionName))
    throw new Error('OTA runtimeVersion must be the native Android x.y.z versionName.');
  if (!isInstalled()) throw new Error('Install expo-updates and commit the lockfile before enabling OTA.');
  return {
    projectId, channel, runtimeVersion: versionName,
    updates: {
      url: `https://u.expo.dev/${projectId}`,
      requestHeaders: { 'expo-channel-name': channel },
      checkAutomatically: 'ON_LOAD', fallbackToCacheTimeout: 0,
    },
  };
}
module.exports = { otaUpdateConfig };
