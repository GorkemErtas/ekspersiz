import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
const cli = 'node_modules/expo/bin/cli';
const run = (env) =>
  spawnSync(process.execPath, [cli, 'config', '--type', 'public', '--json'], {
    encoding: 'utf8',
    timeout: 60_000,
    env: { ...process.env, ...env },
  });
const development = run({ APP_VARIANT: 'development' });
assert.equal(development.status, 0, development.stderr);
const config = JSON.parse(development.stdout);
assert.equal(config.android.package, 'com.gorkem.ekspersiz.dev');
assert.equal(config.ios.bundleIdentifier, 'com.gorkem.ekspersiz.dev');
assert.ok(
  config.android.permissions.includes('android.permission.RECORD_AUDIO'),
);
assert.ok(
  config.android.permissions.includes('android.permission.POST_NOTIFICATIONS'),
);
for (const permission of [
  'READ_EXTERNAL_STORAGE',
  'WRITE_EXTERNAL_STORAGE',
  'READ_MEDIA_IMAGES',
  'READ_MEDIA_VIDEO',
])
  assert.ok(
    config.android.blockedPermissions.includes(
      `android.permission.${permission}`,
    ),
  );
const production = run({ APP_VARIANT: 'production' });
assert.notEqual(production.status, 0);
assert.match(production.stderr, /Production builds require/);
const secret = run({
  APP_VARIANT: 'development',
  EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY: 'sk_test_forbidden',
});
assert.notEqual(secret.status, 0);
assert.match(secret.stderr, /Never bundle a secret API key/);
console.log(
  'Development identity/permissions, production guard and RevenueCat secret-key rejection verified.',
);
