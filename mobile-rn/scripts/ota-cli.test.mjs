import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { join } from 'node:path';

const cliRoot =
  process.env.OTA_EAS_CLI_ROOT ??
  join(
    process.platform === 'win32'
      ? join(process.env.APPDATA, 'npm/node_modules')
      : execFileSync('npm', ['root', '--global'], { encoding: 'utf8' }).trim(),
    'eas-cli',
  );
for (const scenario of [
  'missing-local',
  'missing-github',
  'missing-ci',
  'missing-eas-build',
  'valid',
  'public-drift',
  'firebase-drift',
  'variant-drift',
  'bundle-drift',
  'server-failure',
])
  test(
    `real EAS CLI 27.2.0 non-publishing preflight: ${scenario}`,
    { timeout: 120000 },
    () => {
      const env = { ...process.env, OTA_EAS_CLI_ROOT: cliRoot };
      for (const name of ['EXPO_TOKEN', 'GITHUB_TOKEN', 'GH_TOKEN'])
        delete env[name];
      const result = spawnSync(
        process.execPath,
        ['scripts/ota-cli-preflight.mjs', scenario],
        { env, encoding: 'utf8', timeout: 110000 },
      );
      assert.equal(result.status, 0, result.stderr + result.stdout);
      assert.match(result.stdout, /"stoppedBeforeUpload":true/);
    },
  );
