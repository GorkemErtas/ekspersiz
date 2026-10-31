import test from 'node:test';
import assert from 'node:assert/strict';
import {
  androidReleaseConfig,
  productionApi,
} from '../config/androidRelease.cjs';
import signing from '../plugins/withAndroidRelease.cjs';
import { checkManifest } from './check-android-manifest.mjs';

// Synthetic config fixtures only; tests never generate a key, native release or signed production artifact.
const sha1 = '12'.repeat(20);
const fixture = () => ({
  EXPO_NO_DOTENV: '1',
  APP_VARIANT: 'production',
  EXPO_PUBLIC_API_BASE_URL: productionApi,
  EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY: 'goog_fixture',
  EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY: 'AIza' + 'x'.repeat(35),
  EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID: 'fixture-web.apps.googleusercontent.com',
  GOOGLE_SERVICES_FILE: 'fixture.json',
  ANDROID_VERSION_NAME: '1.0.2',
  ANDROID_VERSION_CODE: '54',
  ANDROID_PLAY_MAX_VERSION_CODE: '53',
  ANDROID_PLAY_SIGNING_SHA1: sha1,
  ANDROID_PLAY_SIGNING_SHA256: '34'.repeat(32),
  ANDROID_KEYSTORE_PROPERTIES_FILE: 'fixture.properties',
  ANDROID_KEYSTORE_BASE_DIR: '.',
});
const firebase = () => ({
  project_info: { project_id: 'fixture-project', project_number: '123' },
  client: [
    {
      client_info: {
        android_client_info: { package_name: 'com.gorkem.ekspersiz' },
      },
      oauth_client: [
        {
          client_type: 3,
          client_id: fixture().EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID,
        },
        {
          client_type: 1,
          client_id: 'fixture-android',
          android_info: {
            package_name: 'com.gorkem.ekspersiz',
            certificate_hash: sha1,
          },
        },
      ],
    },
  ],
});
const evaluate = (env = fixture(), json = firebase(), exists = () => true) =>
  androidReleaseConfig(env, process.cwd(), () => JSON.stringify(json), exists);

test('production config binds the original package, web OAuth and verified Play SHA-1', () => {
  assert.equal(evaluate().versionCode, 54);
  assert.equal(evaluate().versionName, '1.0.2');
  assert.equal(evaluate().sha1, sha1);
  const bad = firebase();
  bad.client[0].client_info.android_client_info.package_name += '.dev';
  assert.throws(() => evaluate(fixture(), bad), /production Android/);
  assert.throws(
    () =>
      evaluate({
        ...fixture(),
        EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID: 'fixture-android',
      }),
    /type 3/,
  );
  assert.throws(
    () =>
      evaluate({ ...fixture(), ANDROID_PLAY_SIGNING_SHA1: '56'.repeat(20) }),
    /Play App Signing/,
  );
});

test('each mandatory production input fails closed when missing', () => {
  for (const name of Object.keys(fixture())) {
    const env = fixture();
    delete env[name];
    assert.throws(() => evaluate(env), undefined, name);
  }
  assert.throws(
    () => evaluate(fixture(), firebase(), () => false),
    /upload signing/,
  );
});

test('reused version codes, cleartext/wrong hosts, test RC keys and extra public secrets are rejected', () => {
  for (const change of [
    { ANDROID_VERSION_CODE: '53' },
    { ANDROID_PLAY_MAX_VERSION_CODE: '54' },
    { ANDROID_VERSION_CODE: 'NaN' },
    { ANDROID_VERSION_CODE: '2100000001' },
    { EXPO_PUBLIC_API_BASE_URL: 'http://10.0.2.2:8080/api/v1' },
    { EXPO_PUBLIC_API_BASE_URL: 'https://example.com/api/v1' },
    { EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY: 'test_fixture' },
    { EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY: 'sk_fixture' },
    { EXPO_PUBLIC_GEMINI_API_KEY: 'forbidden' },
    { ANDROID_PLAY_SIGNING_SHA256: 'invalid' },
  ])
    assert.throws(() => evaluate({ ...fixture(), ...change }));
});

test('production native generation removes debug release signing and retains fail-closed signing/tooling checks', () => {
  const original =
    'android { buildTypes { debug { signingConfig signingConfigs.debug } release { signingConfig signingConfigs.debug } } }';
  const result = signing.configureSigning(original, true);
  assert.match(result, /signingConfig signingConfigs.productionUpload/);
  assert.equal(
    (result.match(/signingConfig signingConfigs.debug/g) ?? []).length,
    1,
  );
  assert.match(result, /hermesEnabled/);
  assert.match(result, /debuggable false/);
  assert.match(result, /minifyEnabled true/);
  assert.match(result, /shrinkResources true/);
  assert.equal(signing.configureSigning(result, true), result);
  assert.equal(signing.configureSigning(result, false).trim(), original);
  assert.throws(
    () => signing.configureSigning('unknown Gradle template', true),
    /Unexpected/,
  );
});

test('release manifest rejects development permissions, debug mode, wrong package and cleartext', () => {
  const permissions = [
    'CAMERA',
    'RECORD_AUDIO',
    'POST_NOTIFICATIONS',
    'INTERNET',
    'ACCESS_FINE_LOCATION',
    'ACCESS_COARSE_LOCATION',
  ]
    .map(
      (name) => `<uses-permission android:name="android.permission.${name}"/>`,
    )
    .join('');
  const xml = `<manifest package="com.gorkem.ekspersiz" android:versionCode="54" android:versionName="1.0.2">${permissions}<uses-permission android:name="com.android.vending.BILLING"/>
    <application android:usesCleartextTraffic="false" android:allowBackup="false"><service><action android:name="com.google.firebase.MESSAGING_EVENT"/></service>
    <provider android:name="androidx.startup.InitializationProvider"><meta-data android:name="androidx.work.WorkManagerInitializer" android:value="androidx.startup"/></provider>
    <meta-data android:name="com.google.android.geo.API_KEY"/>
    <meta-data android:name="firebase_messaging_auto_init_enabled" android:value="false"/></application></manifest>`;
  const options = {
    release: true,
    production: true,
    versionCode: 54,
    versionName: '1.0.2',
  };
  checkManifest(xml, options);
  for (const invalid of [
    xml.replace('<application ', '<application android:debuggable="true" '),
    xml.replace('com.gorkem.ekspersiz"', 'com.gorkem.ekspersiz.dev"'),
    xml.replace('usesCleartextTraffic="false"', 'usesCleartextTraffic="true"'),
    xml.replace(
      '</manifest>',
      '<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/></manifest>',
    ),
    xml.replace('versionCode="54"', 'versionCode="53"'),
    xml.replace('versionName="1.0.2"', 'versionName="1.0.1"'),
    xml.replace('androidx.work.WorkManagerInitializer', 'removed.Initializer'),
    xml.replace('android:value="false"', 'android:value="true"'),
  ])
    assert.throws(() => checkManifest(invalid, options));
});
