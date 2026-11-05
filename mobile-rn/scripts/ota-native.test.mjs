import test from 'node:test';
import assert from 'node:assert/strict';
import { inspectManifestDump, verifyNativeOta } from './ota-inspect-binary.mjs';
import { easProject } from '../config/productionEnvironment.cjs';
const runtime = 'a'.repeat(40);
const badging =
  "package: name='com.gorkem.ekspersiz' versionCode='55' versionName='1.0.3'";
const meta = (name, value) =>
  `E: meta-data\n A: android:name(0x01010003)=${JSON.stringify('expo.modules.updates.' + name)}\n A: android:value(0x01010024)=${typeof value === 'string' && !value.startsWith('@') ? JSON.stringify(value) : value}\n`;
const manifest = () =>
  meta('ENABLED', true) +
  meta('EXPO_UPDATE_URL', `https://u.expo.dev/${easProject.id}`) +
  meta('EXPO_RUNTIME_VERSION', '@0x7f120001') +
  meta(
    'UPDATES_CONFIGURATION_REQUEST_HEADERS_KEY',
    JSON.stringify({ 'expo-channel-name': 'staging' }),
  ) +
  meta('EXPO_UPDATES_CHECK_ON_LAUNCH', 'ALWAYS') +
  meta('EXPO_UPDATES_LAUNCH_WAIT_MS', 0);
const resources = `resource 0x7f120001 string/expo_runtime_version\n () "${runtime}"\n`;

test('compiled Android metadata verifies the embedded channel, fingerprint runtime and nonblocking startup policy', () => {
  const report = inspectManifestDump(manifest(), resources, badging);
  assert.equal(report.otaCapable, true);
  assert.equal(report.versionCode, 55);
  assert.equal(report.channel, 'staging');
  assert.equal(report.runtimeVersion, runtime);
  assert.equal(
    verifyNativeOta(report, { channel: 'staging', runtimeVersion: runtime }),
    report,
  );
  for (const change of [
    { updatesEnabled: false, otaCapable: false },
    { channel: 'production' },
    { runtimeVersion: '1.0.3' },
    { updateUrl: 'https://wrong.invalid' },
    { launchWaitMs: 30000 },
    { startupCheck: 'NEVER' },
  ])
    assert.throws(() =>
      verifyNativeOta(
        { ...report, ...change },
        { channel: 'staging', runtimeVersion: runtime },
      ),
    );
});
test('disabled historical APKs are identified without assuming a Play version maximum or current installation', () => {
  const report = inspectManifestDump(meta('ENABLED', false), '', badging);
  assert.equal(report.otaCapable, false);
  assert.equal(report.runtimeVersion, null);
  assert.throws(() =>
    verifyNativeOta(report, { channel: 'production', runtimeVersion: runtime }),
  );
  assert.throws(
    () =>
      inspectManifestDump(
        manifest(),
        resources,
        badging.replace('com.gorkem.ekspersiz', 'com.gorkem.ekspersiz.dev'),
      ),
    /production package/,
  );
});
