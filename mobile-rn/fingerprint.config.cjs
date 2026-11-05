'use strict';

// Routing changes where an update is delivered, not the native ABI. Keep every
// other Expo config value, plugin, native dependency and native asset in the hash.
function fileHookTransform(source, chunk) {
  if (source.type === 'contents' && source.id === 'expoConfig' && chunk) {
    const config = JSON.parse(String(chunk));
    const headers = config.updates?.requestHeaders;
    if (headers?.['expo-channel-name']) {
      if (!['staging', 'production'].includes(headers['expo-channel-name']))
        throw new Error('Unknown fingerprint delivery channel.');
      headers['expo-channel-name'] = '<delivery-channel>';
    }
    return JSON.stringify(config);
  }
  return chunk;
}
module.exports = {
  preset: 'balanced',
  nativeModuleSourceType: 'files',
  configPluginSourceType: 'files',
  extraSources: [
    'fingerprint.config.cjs',
    'config/productionEnvironment.cjs',
    'config/otaUpdate.cjs',
    'config/otaPublication.cjs',
    'config/androidRelease.cjs',
  ]
    .map((filePath) => ({
      type: 'file',
      filePath,
      reasons: ['reviewedOtaNativeContract'],
    }))
    .concat(
      ['modules', 'src/platform'].map((filePath) => ({
        type: 'dir',
        filePath,
        reasons: ['nativeBridgeContract'],
      })),
    ),
  fileHookTransform,
};
