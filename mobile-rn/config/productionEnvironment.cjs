'use strict';
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { createHash } = require('node:crypto');

const productionPackage = 'com.gorkem.ekspersiz';
const productionApi =
  'https://ekspersiz-backend-production.up.railway.app/api/v1';
const easProject = Object.freeze({
  owner: 'trertas',
  slug: 'ekspersiz-mobile',
  id: '883c68ec-f7e4-4c3e-87e2-e989c4b4b859',
});
const publicEnvironmentNames = Object.freeze([
  'EXPO_PUBLIC_API_BASE_URL',
  'EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID',
  'EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY',
  'EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY',
]);
const signingEnvironmentNames = Object.freeze([
  'ANDROID_KEYSTORE_PROPERTIES_FILE',
  'ANDROID_KEYSTORE_BASE_DIR',
  'ANDROID_KEYSTORE_PASSWORD',
  'ANDROID_KEY_PASSWORD',
  'ANDROID_SIGNING_STORE_PASSWORD',
]);
function required(env, name) {
  const value = env[name]?.trim();
  if (!value) throw new Error(`Production builds require ${name}.`);
  return value;
}
function productionEnvironmentConfig(
  env,
  root,
  read = (path) => readFileSync(path, 'utf8'),
) {
  if (env.APP_VARIANT !== 'production')
    throw new Error('Production builds require APP_VARIANT=production.');
  if (env.EXPO_NO_DOTENV !== '1')
    throw new Error(
      'Production builds require EXPO_NO_DOTENV=1; development dotenv files are forbidden.',
    );
  for (const name of Object.keys(env)) {
    if (
      name.startsWith('EXPO_PUBLIC_') &&
      !publicEnvironmentNames.includes(name)
    )
      throw new Error(`Unexpected public release variable: ${name}.`);
  }
  const mode = env.APP_CONFIG_MODE ?? 'native';
  if (!['native', 'ota'].includes(mode))
    throw new Error('APP_CONFIG_MODE must be native or ota.');
  if (mode === 'ota' && signingEnvironmentNames.some((name) => env[name]))
    throw new Error(
      'Signing credentials must not be available in OTA publishing.',
    );
  if (required(env, 'EXPO_PUBLIC_API_BASE_URL') !== productionApi)
    throw new Error(
      'Production API must use the existing HTTPS backend /api/v1.',
    );
  if (
    !/^goog_[A-Za-z0-9]+$/.test(
      required(env, 'EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY'),
    )
  )
    throw new Error(
      'Production requires the Android RevenueCat public goog_ SDK key; test/secret keys are forbidden.',
    );
  if (
    !/^AIza[A-Za-z0-9_-]{35}$/.test(
      required(env, 'EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY'),
    )
  )
    throw new Error(
      'Production requires the existing Android Maps SDK API key.',
    );
  const webClient = required(env, 'EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID');
  const versionName = required(env, 'ANDROID_VERSION_NAME');
  if (!/^\d+\.\d+\.\d+$/.test(versionName))
    throw new Error(
      'ANDROID_VERSION_NAME must be a numeric x.y.z release version.',
    );
  const code = required(env, 'ANDROID_VERSION_CODE');
  const versionCode = Number(code);
  if (
    !/^[1-9]\d*$/.test(code) ||
    !Number.isSafeInteger(versionCode) ||
    versionCode > 2_100_000_000
  )
    throw new Error(
      'ANDROID_VERSION_CODE must be a valid existing or new native versionCode.',
    );
  const googleServicesFile = resolve(
    root,
    required(env, 'GOOGLE_SERVICES_FILE'),
  );
  let firebase;
  try {
    firebase = JSON.parse(read(googleServicesFile));
  } catch {
    throw new Error('Production Firebase client JSON cannot be read.');
  }
  if (
    JSON.stringify(firebase).includes('"private_key"') ||
    firebase.type === 'service_account'
  )
    throw new Error(
      'Use Firebase Android client JSON, never service-account credentials.',
    );
  const clients = firebase.client?.filter(
    (client) =>
      client.client_info?.android_client_info?.package_name ===
      productionPackage,
  );
  if (
    clients?.length !== 1 ||
    !firebase.project_info?.project_id ||
    !firebase.project_info?.project_number
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
  const publicValues = Object.fromEntries(
    publicEnvironmentNames.map((name) => [name, required(env, name)]),
  );
  const environmentHash = createHash('sha256')
    .update(JSON.stringify({ ...publicValues, firebase }))
    .digest('hex');
  return {
    versionName,
    versionCode,
    googleServicesFile,
    firebase,
    oauth,
    environmentHash,
  };
}
module.exports = {
  productionPackage,
  productionApi,
  easProject,
  publicEnvironmentNames,
  signingEnvironmentNames,
  required,
  productionEnvironmentConfig,
};
