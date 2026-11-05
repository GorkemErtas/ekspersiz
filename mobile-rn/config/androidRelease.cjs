const { readFileSync, existsSync } = require('node:fs');
const { resolve } = require('node:path');

const {
  productionPackage,
  productionApi,
  productionEnvironmentConfig,
  required,
} = require('./productionEnvironment.cjs');

const releaseEnvironmentNames = new Set([
  'APP_VARIANT',
  'APP_CONFIG_MODE',
  'EXPO_UPDATES_ENABLED',
  'EXPO_UPDATES_PROJECT_ID',
  'EXPO_UPDATES_CHANNEL',
  'EXPO_PUBLIC_API_BASE_URL',
  'EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID',
  'EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY',
  'EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY',
  'GOOGLE_SERVICES_FILE',
  'ANDROID_VERSION_NAME',
  'ANDROID_VERSION_CODE',
  'ANDROID_PLAY_MAX_VERSION_CODE',
  'ANDROID_PLAY_SIGNING_SHA1',
  'ANDROID_PLAY_SIGNING_SHA256',
  'ANDROID_KEYSTORE_PROPERTIES_FILE',
  'ANDROID_KEYSTORE_BASE_DIR',
]);

function normalizeFingerprint(value, bytes) {
  const normalized = value.replace(/:/g, '').toUpperCase();
  if (!new RegExp(`^[0-9A-F]{${bytes * 2}}$`).test(normalized))
    throw new Error(`Invalid SHA-${bytes === 20 ? '1' : '256'} fingerprint.`);
  return normalized;
}

function androidReleaseConfig(
  env,
  projectRoot,
  read = (path) => readFileSync(path, 'utf8'),
  exists = existsSync,
) {
  if (env.APP_CONFIG_MODE && env.APP_CONFIG_MODE !== 'native')
    throw new Error(
      'Native release validation requires APP_CONFIG_MODE=native.',
    );
  const shared = productionEnvironmentConfig(env, projectRoot, read);
  const need = (name) => required(env, name);
  const sha1 = normalizeFingerprint(need('ANDROID_PLAY_SIGNING_SHA1'), 20);
  const sha256 = normalizeFingerprint(need('ANDROID_PLAY_SIGNING_SHA256'), 32);
  const { versionName, versionCode, googleServicesFile, firebase, oauth } =
    shared;
  const previous = Number(need('ANDROID_PLAY_MAX_VERSION_CODE'));
  if (
    !Number.isSafeInteger(previous) ||
    previous < 1 ||
    !Number.isSafeInteger(versionCode) ||
    versionCode <= previous ||
    versionCode > 2_100_000_000
  )
    throw new Error(
      'Production versionCode must exceed the verified maximum across all Play tracks/drafts.',
    );

  if (
    !oauth.some(
      (client) =>
        client.client_type === 1 &&
        client.android_info?.package_name === productionPackage &&
        client.android_info.certificate_hash
          ?.replace(/:/g, '')
          .toUpperCase() === sha1,
    )
  )
    throw new Error(
      'Play App Signing SHA-1 is missing from the production Android OAuth configuration.',
    );

  const signingPropertiesFile = resolve(
    projectRoot,
    need('ANDROID_KEYSTORE_PROPERTIES_FILE'),
  );
  const signingBaseDirectory = resolve(
    projectRoot,
    need('ANDROID_KEYSTORE_BASE_DIR'),
  );
  if (!exists(signingPropertiesFile) || !exists(signingBaseDirectory))
    throw new Error(
      'Existing Flutter upload signing properties/base directory are unavailable. No new key will be generated.',
    );
  return {
    versionName,
    versionCode,
    googleServicesFile,
    signingPropertiesFile,
    signingBaseDirectory,
    sha1,
    sha256,
    firebaseProject: firebase.project_info.project_id,
  };
}

exports.productionPackage = productionPackage;
exports.productionApi = productionApi;
exports.releaseEnvironmentNames = releaseEnvironmentNames;
exports.normalizeFingerprint = normalizeFingerprint;
exports.androidReleaseConfig = androidReleaseConfig;
