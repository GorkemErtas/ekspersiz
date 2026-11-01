import test from 'node:test';
import assert from 'node:assert/strict';
import ota from '../config/otaUpdate.cjs';
const config = (env = {}, options = {}) => ota.otaUpdateConfig({
  EXPO_UPDATES_ENABLED: '1',
  EXPO_UPDATES_PROJECT_ID: '12345678-1234-4123-8123-123456789abc',
  EXPO_UPDATES_CHANNEL: 'staging',
  ...env,
}, {production: true, versionName: '1.0.3', isInstalled: () => true, ...options});
test('disabled by default; no stray project/channel', () => {
  assert.equal(ota.otaUpdateConfig({}, {production: true, versionName: '1.0.3'}), null);
  assert.throws(() => config({EXPO_UPDATES_ENABLED: '0'}), /requires EXPO_UPDATES_ENABLED/);
});
test('valid channel and native runtime mapping', () => {
  const result = config();
  assert.equal(result.runtimeVersion, '1.0.3');
  assert.equal(result.updates.requestHeaders['expo-channel-name'], 'staging');
  assert.equal(result.updates.url, 'https://u.expo.dev/12345678-1234-4123-8123-123456789abc');
  assert.equal(config({EXPO_UPDATES_CHANNEL: 'production'}).channel, 'production');
});
test('invalid identity, native mode, dependency, channel and runtime fail closed', () => {
  for (const value of [
    {EXPO_UPDATES_ENABLED: 'true'},
    {EXPO_UPDATES_PROJECT_ID: 'invalid'},
    {EXPO_UPDATES_PROJECT_ID: ''},
    {EXPO_UPDATES_CHANNEL: ''},
    {EXPO_UPDATES_CHANNEL: 'preview'},
  ]) assert.throws(() => config(value));
  assert.throws(() => config({}, {production: false}), /production Android/);
  assert.throws(() => config({}, {versionName: 'broken'}), /runtimeVersion/);
  assert.throws(() => config({}, {isInstalled: () => false}), /expo-updates/);
});
