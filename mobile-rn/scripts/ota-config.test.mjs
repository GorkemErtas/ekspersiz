import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { otaUpdateConfig } from '../config/otaUpdate.cjs';
import {
  easProject,
  productionEnvironmentConfig,
} from '../config/productionEnvironment.cjs';
import { androidReleaseConfig } from '../config/androidRelease.cjs';
import fingerprint from '../fingerprint.config.cjs';
import { firebase, publicEnv } from './ota-fixtures.mjs';
const config = (env = {}, options = {}) =>
  otaUpdateConfig(
    { ...publicEnv(), ...env },
    { production: true, isInstalled: () => true, ...options },
  );
const shared = (env = {}) =>
  productionEnvironmentConfig({ ...publicEnv(), ...env }, process.cwd(), () =>
    JSON.stringify(firebase()),
  );

test('OTA is disabled by default and explicit enablement is fail-closed', () => {
  assert.equal(otaUpdateConfig({}, { production: false }), null);
  for (const change of [
    { EXPO_UPDATES_ENABLED: '0' },
    { EXPO_UPDATES_ENABLED: 'true' },
    { EXPO_UPDATES_PROJECT_ID: undefined },
    { EXPO_UPDATES_PROJECT_ID: '12345678-1234-4123-8123-123456789abc' },
    { EXPO_UPDATES_PROJECT_ID: 'invalid' },
    { EXPO_UPDATES_CHANNEL: undefined },
    { EXPO_UPDATES_CHANNEL: 'preview' },
    { EAS_BUILD_CHANNEL: 'production' },
  ])
    assert.throws(() => config(change));
  assert.throws(() => config({}, { production: false }), /production Android/);
  assert.throws(() => config({}, { isInstalled: () => false }), /expo-updates/);
});

test('both channels use the registered project, fingerprint runtime and native startup recovery', () => {
  for (const channel of ['staging', 'production']) {
    const result = config({ EXPO_UPDATES_CHANNEL: channel });
    assert.deepEqual(result.runtimeVersion, { policy: 'fingerprint' });
    assert.equal(result.updates.requestHeaders['expo-channel-name'], channel);
    assert.equal(result.updates.url, `https://u.expo.dev/${easProject.id}`);
    assert.equal(result.updates.fallbackToCacheTimeout, 0);
    assert.equal(result.updates.checkAutomatically, 'ON_LOAD');
    assert.equal(result.updates.disableAntiBrickingMeasures, false);
    assert.equal(result.updates.useEmbeddedUpdate, true);
  }
});

test('OTA production environment needs no signing files or Play version increment', () => {
  assert.equal(shared().versionCode, 55);
  assert.equal(
    shared().environmentHash,
    shared({ EXPO_UPDATES_CHANNEL: 'production' }).environmentHash,
  );
  assert.throws(
    () =>
      androidReleaseConfig(publicEnv(), process.cwd(), () =>
        JSON.stringify(firebase()),
      ),
    /native/,
  );
  assert.throws(
    () =>
      androidReleaseConfig(
        { ...publicEnv(), APP_CONFIG_MODE: 'native' },
        process.cwd(),
        () => JSON.stringify(firebase()),
      ),
    /ANDROID_PLAY_SIGNING_SHA1/,
  );
  for (const name of [
    'ANDROID_KEYSTORE_PROPERTIES_FILE',
    'ANDROID_KEYSTORE_BASE_DIR',
    'ANDROID_KEYSTORE_PASSWORD',
  ])
    assert.throws(
      () => shared({ [name]: 'must-not-be-loaded' }),
      /Signing credentials/,
    );
});

test('public environment validation rejects wrong API, test keys, extra public secrets, invalid metadata and versions', () => {
  for (const env of [
    { EXPO_NO_DOTENV: undefined },
    { EXPO_PUBLIC_API_BASE_URL: 'http://localhost:18080/api/v1' },
    { EXPO_PUBLIC_API_BASE_URL: 'https://example.com/api/v1' },
    { EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY: 'test_fixture' },
    { EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY: '' },
    { EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID: 'wrong-client' },
    { EXPO_PUBLIC_SECRET_KEY: 'forbidden' },
    { ANDROID_VERSION_NAME: 'bad' },
    { ANDROID_VERSION_CODE: '1e2' },
    { ANDROID_VERSION_CODE: '0' },
    { APP_CONFIG_MODE: 'unsafe' },
  ])
    assert.throws(() => shared(env));
  const bad = firebase();
  bad.client[0].client_info.android_client_info.package_name += '.dev';
  assert.throws(
    () =>
      productionEnvironmentConfig(publicEnv(), '.', () => JSON.stringify(bad)),
    /production Android/,
  );
});

test('fingerprint normalization ignores only channel routing and preserves native/security settings', () => {
  const transform = (channel, changes = {}) =>
    fingerprint.fileHookTransform(
      { type: 'contents', id: 'expoConfig' },
      JSON.stringify({
        android: { package: 'com.gorkem.ekspersiz' },
        updates: {
          url: `https://u.expo.dev/${easProject.id}`,
          requestHeaders: { 'expo-channel-name': channel },
        },
        ...changes,
      }),
    );
  assert.equal(transform('staging'), transform('production'));
  assert.notEqual(
    transform('staging'),
    transform('staging', { android: { package: 'com.gorkem.ekspersiz.dev' } }),
  );
  assert.notEqual(
    transform('staging'),
    transform('staging', { extra: { productionEnvironmentHash: 'different' } }),
  );
  assert.throws(() => transform('wrong'), /Unknown fingerprint/);
});

test('real Expo config supports OTA without signing credentials while native evaluation still fails closed', () => {
  const directory = mkdtempSync(join(tmpdir(), 'ekspersiz-ota-config-'));
  const file = join(directory, 'firebase.json');
  writeFileSync(file, JSON.stringify(firebase()));
  const clean = { ...process.env };
  for (const name of Object.keys(clean))
    if (
      name.startsWith('EXPO_PUBLIC_') ||
      name.startsWith('ANDROID_') ||
      name.startsWith('EXPO_UPDATES_') ||
      name.startsWith('GOOGLE_')
    )
      delete clean[name];
  const run = (env) =>
    spawnSync(
      process.execPath,
      ['node_modules/expo/bin/cli', 'config', '--type', 'public', '--json'],
      {
        cwd: resolve('.'),
        env: { ...clean, ...env },
        encoding: 'utf8',
        timeout: 60000,
      },
    );
  try {
    for (const channel of ['staging', 'production']) {
      const result = run({ ...publicEnv(file), EXPO_UPDATES_CHANNEL: channel });
      assert.equal(result.status, 0, result.stderr);
      const exp = JSON.parse(result.stdout);
      assert.equal(exp.android.package, 'com.gorkem.ekspersiz');
      assert.equal(exp.owner, easProject.owner);
      assert.equal(exp.extra.eas.projectId, easProject.id);
      assert.equal(exp.updates.requestHeaders['expo-channel-name'], channel);
      assert.deepEqual(exp.runtimeVersion, { policy: 'fingerprint' });
      assert.ok(exp.extra.productionEnvironmentHash);
      assert.doesNotMatch(
        result.stdout,
        /signingPropertiesFile|signingBaseDirectory|storePassword/,
      );
    }
    const native = run({ ...publicEnv(file), APP_CONFIG_MODE: 'native' });
    assert.notEqual(native.status, 0);
    assert.match(native.stderr, /ANDROID_PLAY_SIGNING_SHA1/);
    const dev = run({ APP_VARIANT: 'development', EXPO_NO_DOTENV: '1' });
    assert.equal(JSON.parse(dev.stdout).updates.enabled, false);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
