const { withPlugins } = require('expo/config-plugins');
// Apply the official plugin only to platforms with a matching real Firebase client config.
module.exports = (config) => {
  const android = !!config.android?.googleServicesFile,
    ios = !!config.ios?.googleServicesFile;
  if (!android && !ios) return config;
  const previous = {
    android: { ...config.mods?.android },
    ios: { ...config.mods?.ios },
  };
  config = withPlugins(config, [
    '@react-native-firebase/app',
    '@react-native-firebase/messaging',
  ]);
  if (!android) config.mods.android = previous.android;
  if (!ios) config.mods.ios = previous.ios;
  return config;
};
