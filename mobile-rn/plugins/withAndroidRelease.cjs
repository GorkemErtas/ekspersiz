const {
  withAppBuildGradle,
  withGradleProperties,
} = require('expo/config-plugins');

const start = '// @generated begin ekspersiz-production-signing';
const end = '// @generated end ekspersiz-production-signing';

function configureSigning(contents, production) {
  const begin = contents.indexOf(start);
  if (begin >= 0) {
    const finish = contents.indexOf(end, begin);
    if (finish < 0)
      throw new Error('Incomplete generated production signing block.');
    contents = contents.slice(0, begin) + contents.slice(finish + end.length);
  }
  // Expo's template signs release with debug.keystore. Production must never inherit it.
  const releaseDebugSigning =
    /(release\s*\{[\s\S]*?)signingConfig signingConfigs\.debug/;
  if (!production)
    return contents.replace(
      'signingConfig null // Existing upload key is configured below.',
      'signingConfig signingConfigs.debug',
    );
  if (releaseDebugSigning.test(contents))
    contents = contents.replace(
      releaseDebugSigning,
      '$1signingConfig null // Existing upload key is configured below.',
    );
  else if (
    !contents.includes(
      'signingConfig null // Existing upload key is configured below.',
    )
  )
    throw new Error(
      'Unexpected Expo release signing template; review before generating production native sources.',
    );
  return `${contents.trimEnd()}

${start}
if (System.getenv('APP_VARIANT') != 'production' || System.getenv('EXPO_NO_DOTENV') != '1') {
    throw new GradleException('Production native sources require the explicit release environment. Run npm run release:android.')
}
if (findProperty('hermesEnabled')?.toString() != 'true' ||
    findProperty('expo.devlauncher.configureInRelease')?.toString() == 'true' ||
    findProperty('expo.devmenu.configureInRelease')?.toString() == 'true') {
    throw new GradleException('Production requires Hermes and disabled development tools.')
}
def eksPropertiesPath = System.getenv('ANDROID_KEYSTORE_PROPERTIES_FILE')
def eksBaseDirectory = System.getenv('ANDROID_KEYSTORE_BASE_DIR')
if (!eksPropertiesPath || !eksBaseDirectory) throw new GradleException('Existing upload key configuration is required.')
def eksSigning = new Properties()
new File(eksPropertiesPath).withInputStream { eksSigning.load(it) }
['storeFile', 'storePassword', 'keyAlias', 'keyPassword'].each {
    if (!eksSigning.getProperty(it)) throw new GradleException('Existing upload signing properties are incomplete.')
}
def eksStore = new File(eksSigning.getProperty('storeFile'))
if (!eksStore.isAbsolute()) eksStore = new File(eksBaseDirectory, eksSigning.getProperty('storeFile'))
if (!eksStore.isFile()) throw new GradleException('Existing upload keystore is unavailable.')
android {
    signingConfigs {
        productionUpload {
            storeFile eksStore
            storePassword eksSigning.getProperty('storePassword')
            keyAlias eksSigning.getProperty('keyAlias')
            keyPassword eksSigning.getProperty('keyPassword')
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.productionUpload
            debuggable false
            minifyEnabled true
            shrinkResources true
        }
    }
}
gradle.taskGraph.whenReady { graph ->
    if (graph.hasTask(':app:packageDebug') || graph.hasTask(':app:assembleDebug')) {
        throw new GradleException('The production package cannot be built as a debug application.')
    }
}
${end}
`;
}

module.exports = function withAndroidRelease(
  config,
  { production = false } = {},
) {
  config = withGradleProperties(config, (mod) => {
    for (const key of [
      'expo.devlauncher.configureInRelease',
      'expo.devmenu.configureInRelease',
      'hermesEnabled',
    ]) {
      mod.modResults = mod.modResults.filter((entry) => entry.key !== key);
      mod.modResults.push({
        type: 'property',
        key,
        value: key === 'hermesEnabled' ? 'true' : 'false',
      });
    }
    return mod;
  });
  return withAppBuildGradle(config, (mod) => {
    if (mod.modResults.language !== 'groovy')
      throw new Error('Review production signing for the new Gradle language.');
    mod.modResults.contents = configureSigning(
      mod.modResults.contents,
      production,
    );
    return mod;
  });
};
module.exports.configureSigning = configureSigning;
