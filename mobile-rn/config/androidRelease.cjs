const { readFileSync, existsSync } = require('node:fs');
const { resolve } = require('node:path');

const productionPackage = 'com.gorkem.ekspersiz';
const productionApi =
  'https://ekspersiz-backend-production.up.railway.app/api/v1';

const releaseEnvironmentNames = new Set([
  'APP_VARIANT',
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
  if (env.APP_VARIANT !== 'production')
    throw new Error('Production builds require APP_VARIANT=production.');
  const required = (name) => {
    const value = env[name]?.trim();
    if (!value) throw new Error(`Production builds require ${name}.`);
    return value;
  };
  if (env.EXPO_NO_DOTENV !== '1')
    throw new Error(
      'Production builds require EXPO_NO_DOTENV=1. Use npm run release:android; development .env files must not be loaded.',
    );
  for (const name of Object.keys(env)) {
    if (name.startsWith('EXPO_PUBLIC_') && !releaseEnvironmentNames.has(name))
      throw new Error(`Unexpected public release variable: ${name}.`);
  }
  if (required('EXPO_PUBLIC_API_BASE_URL') !== productionApi)
    throw new Error(
      'Production API must use the existing HTTPS backend /api/v1.',
    );
  if (
    !/^goog_[A-Za-z0-9]+$/.test(
      required('EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY'),
    )
  )
    throw new Error(
      'Production requires the Android RevenueCat public goog_ SDK key; test/secret keys are forbidden.',
    );
  if (
    !/^AIza[A-Za-z0-9_-]{35}$/.test(
      required('EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY'),
    )
  )
    throw new Error(
      'Production requires the existing Android Maps SDK API key.',
    );
  const webClient = required('EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID');
  const sha1 = normalizeFingerprint(required('ANDROID_PLAY_SIGNING_SHA1'), 20);
  const sha256 = normalizeFingerprint(
    required('ANDROID_PLAY_SIGNING_SHA256'),
    32,
  );
  const versionName = required('ANDROID_VERSION_NAME');
  if (!/^\d+\.\d+\.\d+$/.test(versionName))
    throw new Error(
      'ANDROID_VERSION_NAME must be a numeric x.y.z release version.',
    );
  const versionCode = Number(required('ANDROID_VERSION_CODE'));
  const previous = Number(required('ANDROID_PLAY_MAX_VERSION_CODE'));
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

  const googleServicesFile = resolve(
    projectRoot,
    required('GOOGLE_SERVICES_FILE'),
  );
  let firebase;
  try {
    firebase = JSON.parse(read(googleServicesFile));
  } catch {
    throw new Error('Production Firebase client JSON cannot be read.');
  }
  const clients = firebase.client?.filter(
    (client) =>
      client.client_info?.android_client_info?.package_name ===
      productionPackage,
  );
  if (
    clients?.length !== 1 ||
    !firebase.project_info?.project_id ||
    !firebase.project_info.project_number
  )
    throw new Error(
      'Firebase must contain the existing production Android application/project.',
    );
  const oauth = clients[0].oauth_client ?? [];
  if (
    !oauth.some(
      (client) => client.client_type === 3 && client.client_id === webClient,
    )
  )
    throw new Error(
      'Google Web Client ID must match the production Firebase web/server OAuth client (type 3).',
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
    required('ANDROID_KEYSTORE_PROPERTIES_FILE'),
  );
  const signingBaseDirectory = resolve(
    projectRoot,
    required('ANDROID_KEYSTORE_BASE_DIR'),
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
