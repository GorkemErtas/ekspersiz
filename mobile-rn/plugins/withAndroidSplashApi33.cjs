const {
  withAndroidStyles,
  AndroidConfig,
  XML,
} = require('expo/config-plugins');
const path = require('node:path');

function splitSplashStyle(styles) {
  const splash = styles.resources.style?.find(
    (style) => style.$.name === 'Theme.App.SplashScreen',
  );
  const attribute = 'android:windowSplashScreenBehavior';
  if (!splash?.item?.some((item) => item.$.name === attribute)) return;
  // Android selects a whole style bag: retain every original item on API 33+.
  const api33 = structuredClone(splash);
  splash.item = splash.item.filter((item) => item.$.name !== attribute);
  return api33;
}

// Register BEFORE expo-splash-screen: Expo mod interceptors execute in reverse
// order, so we receive its final generated style. No SDK fork or lint suppression.
module.exports = (config) =>
  withAndroidStyles(config, async (mod) => {
    const style = splitSplashStyle(mod.modResults);
    if (!style) return mod;
    const directory = path.join(
      mod.modRequest.platformProjectRoot,
      'app/src/main/res/values-v33',
    );
    const target = path.join(directory, 'styles.xml');
    const xml = await AndroidConfig.Resources.readResourcesXMLAsync({
      path: target,
    });
    xml.resources.style = [
      ...(xml.resources.style ?? []).filter(
        (entry) => entry.$.name !== style.$.name,
      ),
      style,
    ];
    await XML.writeXMLAsync({ path: target, xml });
    return mod;
  });
module.exports.splitSplashStyle = splitSplashStyle;
