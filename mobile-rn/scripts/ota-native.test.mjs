import test from 'node:test';
import assert from 'node:assert/strict';
import { inspectManifestDump, verifyNativeOta } from './ota-inspect-binary.mjs';
import { easProject } from '../config/productionEnvironment.cjs';
const runtime = 'a'.repeat(40);
const badging =
  "package: name='com.gorkem.ekspersiz' versionCode='55' versionName='1.0.3'";
// aapt2 prints the contents verbatim, including quotes/backslashes, then an
// optional Raw annotation. JSON.stringify(value) is not its string format.
const stringValue = (value) => `"${value}" (Raw: "${value}")`;
const meta = (name, value) =>
  `E: meta-data\n A: android:name(0x01010003)=${stringValue('expo.modules.updates.' + name)}\n A: android:value(0x01010024)=${value}\n`;
const manifest = (overrides = {}) =>
  Object.entries({
    ENABLED: 'true',
    EXPO_UPDATE_URL: stringValue(`https://u.expo.dev/${easProject.id}`),
    EXPO_RUNTIME_VERSION: '@0x7f120001',
    UPDATES_CONFIGURATION_REQUEST_HEADERS_KEY: stringValue(
      '{"expo-channel-name":"staging"}',
    ),
    EXPO_UPDATES_CHECK_ON_LAUNCH: stringValue('ALWAYS'),
    EXPO_UPDATES_LAUNCH_WAIT_MS: '0',
    ...overrides,
  })
    .filter(([, value]) => value !== undefined)
    .map(([name, value]) => meta(name, value))
    .join('');
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

test('aapt2 verbatim JSON strings decode with or without Raw annotations and Android namespace URLs', () => {
  for (const headers of [
    '"{"expo-channel-name":"staging"}" (Raw: "{"expo-channel-name":"staging"}")',
    '"{"expo-channel-name":"staging"}"',
    stringValue(
      JSON.stringify({
        'expo-channel-name': 'staging',
        extra: 'quoted "value", C:\\updates\\file, key=value (Raw: "text")',
      }),
    ),
  ]) {
    for (const namespace of [
      'android:',
      'http://schemas.android.com/apk/res/android:',
    ]) {
      const dump = manifest({
        UPDATES_CONFIGURATION_REQUEST_HEADERS_KEY: headers,
      })
        .replaceAll('android:', namespace)
        .replaceAll('\n', '\r\n');
      const report = inspectManifestDump(dump, resources, badging);
      assert.equal(report.channel, 'staging');
      assert.equal(report.updateUrl, `https://u.expo.dev/${easProject.id}`);
      verifyNativeOta(report, { channel: 'staging', runtimeVersion: runtime });
    }
  }
});

test('aapt2 strings preserve quotes, backslashes, equals signs, whitespace and empty values', () => {
  for (const value of [
    'ALWAYS',
    '',
    '  value with spaces  ',
    'quoted "value" C:\\updates\\file=staging (Raw: "text")',
  ]) {
    for (const printed of [stringValue(value), `"${value}"`]) {
      const report = inspectManifestDump(
        manifest({ EXPO_UPDATES_CHECK_ON_LAUNCH: printed }),
        resources,
        badging,
      );
      assert.equal(report.startupCheck, value);
    }
  }
});

test('aapt2 compiled booleans and decimal/hex integers take precedence over Raw annotations', () => {
  for (const [enabled, expected] of [
    ['true', true],
    ['false', false],
    ['true (Raw: "false")', true],
    ['false (Raw: "true")', false],
  ]) {
    const report = inspectManifestDump(
      manifest({ ENABLED: enabled }),
      resources,
      badging,
    );
    assert.equal(report.updatesEnabled, expected);
    assert.equal(report.otaCapable, expected);
  }
  for (const [wait, expected] of [
    ['0', 0],
    ['-1', -1],
    ['30000 (Raw: "0")', 30000],
    ['0x00000000', 0],
    ['0x00007530 (Raw: "0")', 30000],
  ]) {
    const report = inspectManifestDump(
      manifest({ EXPO_UPDATES_LAUNCH_WAIT_MS: wait }),
      resources,
      badging,
    );
    assert.equal(report.launchWaitMs, expected);
    if (expected === 0)
      verifyNativeOta(report, { channel: 'staging', runtimeVersion: runtime });
    else
      assert.throws(() =>
        verifyNativeOta(report, {
          channel: 'staging',
          runtimeVersion: runtime,
        }),
      );
  }
});

test('aapt2 resource references resolve the compiled ID rather than the Raw resource name', () => {
  for (const value of [
    '@0x7f120001',
    '@0x7f120001 (Raw: "@string/expo_runtime_version")',
    stringValue(runtime),
  ]) {
    const report = inspectManifestDump(
      manifest({ EXPO_RUNTIME_VERSION: value }),
      resources,
      badging,
    );
    assert.equal(report.runtimeVersion, runtime);
    verifyNativeOta(report, { channel: 'staging', runtimeVersion: runtime });
  }
  const unresolved = inspectManifestDump(manifest(), '', badging);
  assert.equal(unresolved.runtimeVersion, null);
  assert.equal(unresolved.otaCapable, false);
  assert.throws(() =>
    verifyNativeOta(unresolved, {
      channel: 'staging',
      runtimeVersion: runtime,
    }),
  );
});

test('malformed embedded header JSON still fails decoding', () => {
  for (const value of ['', '{"expo-channel-name":', '{invalid}', 'staging']) {
    assert.throws(
      () =>
        inspectManifestDump(
          manifest({
            UPDATES_CONFIGURATION_REQUEST_HEADERS_KEY: stringValue(value),
          }),
          resources,
          badging,
        ),
      /Embedded update request headers could not be decoded/,
    );
  }
});

test('real aapt2 metadata retains project, channel, runtime and startup safety gates', () => {
  for (const overrides of [
    { ENABLED: 'false' },
    { ENABLED: 'true-invalid' },
    { EXPO_UPDATE_URL: stringValue('https://u.expo.dev/wrong-project') },
    {
      EXPO_UPDATE_URL: `"https://wrong.invalid" (Raw: "https://u.expo.dev/${easProject.id}")`,
    },
    {
      UPDATES_CONFIGURATION_REQUEST_HEADERS_KEY: stringValue(
        '{"expo-channel-name":"production"}',
      ),
    },
    { UPDATES_CONFIGURATION_REQUEST_HEADERS_KEY: stringValue('{}') },
    { UPDATES_CONFIGURATION_REQUEST_HEADERS_KEY: undefined },
    { EXPO_RUNTIME_VERSION: stringValue('file:fingerprint') },
    { EXPO_RUNTIME_VERSION: stringValue('b'.repeat(40)) },
    { EXPO_UPDATES_CHECK_ON_LAUNCH: stringValue('NEVER') },
    { EXPO_UPDATES_LAUNCH_WAIT_MS: '0-invalid' },
    { EXPO_UPDATES_LAUNCH_WAIT_MS: '0x00007530' },
  ]) {
    const report = inspectManifestDump(manifest(overrides), resources, badging);
    assert.throws(() =>
      verifyNativeOta(report, { channel: 'staging', runtimeVersion: runtime }),
    );
  }
  const report = inspectManifestDump(
    manifest({ EXPO_RUNTIME_VERSION: stringValue('file:fingerprint') }),
    resources,
    badging,
  );
  assert.throws(() =>
    verifyNativeOta(report, {
      channel: 'staging',
      runtimeVersion: 'file:fingerprint',
    }),
  );
});

test('ambiguous Raw delimiters cannot truncate an invalid string into valid OTA metadata', () => {
  assert.throws(
    () =>
      inspectManifestDump(
        manifest({
          EXPO_UPDATE_URL: stringValue(
            `https://u.expo.dev/${easProject.id}" (Raw: "misleading")`,
          ),
        }),
        resources,
        badging,
      ),
    /ambiguous Raw annotation/,
  );
});

test('the legacy request headers key uses the same aapt2 string decoding', () => {
  const report = inspectManifestDump(
    manifest({
      UPDATES_CONFIGURATION_REQUEST_HEADERS_KEY: undefined,
      EXPO_UPDATES_REQUEST_HEADERS: stringValue(
        '{"expo-channel-name":"staging"}',
      ),
    }),
    resources,
    badging,
  );
  assert.equal(report.channel, 'staging');
  verifyNativeOta(report, { channel: 'staging', runtimeVersion: runtime });
});
