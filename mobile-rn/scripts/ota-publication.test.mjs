import { Buffer } from 'node:buffer';
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { firebase, publicEnv } from './ota-fixtures.mjs';
import { productionEnvironmentConfig } from '../config/productionEnvironment.cjs';
import {
  assertPublicationSnapshot,
  createPublicationSnapshot,
  sealPublicationSnapshot,
  snapshotPath,
} from '../config/otaPublication.cjs';
import { inspectOtaExport } from './ota-bundle.mjs';
import { validateUpdateCommand } from './ota-release.mjs';

test('staging command requires exactly one production environment and the validated export', () => {
  const args = [
    'update',
    '--environment',
    'production',
    '--skip-bundler',
    '--input-dir',
    '.ota/export',
  ];
  assert.doesNotThrow(() => validateUpdateCommand(args));
  for (const changed of [
    args.filter((arg) => !['--environment', 'production'].includes(arg)),
    args.map((arg) => (arg === 'production' ? 'preview' : arg)),
    [...args, '--environment', 'production'],
    args.filter((arg) => arg !== '--skip-bundler'),
    args.map((arg) => (arg === '.ota/export' ? 'dist' : arg)),
  ])
    assert.throws(
      () => validateUpdateCommand(changed),
      /--environment production/,
    );
});

test('publication snapshot rejects public, variant, version, channel, Firebase and bundle drift without storing credentials', () => {
  const prefix = join(tmpdir(), 'ota-publication-'),
    root = mkdtempSync(prefix);
  try {
    mkdirSync(join(root, '.ota/export'), { recursive: true });
    mkdirSync(join(root, 'secrets'));
    const file = join(root, 'secrets/google-services.production.json');
    const bytes = JSON.stringify(firebase());
    writeFileSync(file, bytes);
    const env = {
      ...publicEnv('./secrets/google-services.production.json'),
      GOOGLE_SERVICES_JSON_BASE64: Buffer.from(bytes).toString('base64'),
    };
    const environmentHash = productionEnvironmentConfig(
      env,
      root,
    ).environmentHash;
    const snapshot = createPublicationSnapshot(env, root, {
      runtimeVersion: 'a'.repeat(40),
      environmentHash,
    });
    assert.equal(
      assertPublicationSnapshot(env, root).environmentHash,
      environmentHash,
    );
    assert.throws(
      () => createPublicationSnapshot(env, root, snapshot),
      /EEXIST/,
    );
    const persisted = readFileSync(snapshotPath(root), 'utf8');
    assert.ok(
      !persisted.includes('goog_fixture') &&
        !persisted.includes('synthetic-config-test'),
    );
    for (const changed of [
      { EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY: 'goog_changed' },
      { APP_VARIANT: 'development', APP_CONFIG_MODE: 'native' },
      { ANDROID_VERSION_CODE: '99' },
      { EXPO_UPDATES_CHANNEL: 'production' },
      { GOOGLE_SERVICES_FILE: './another.json' },
      { GOOGLE_SERVICES_JSON_BASE64: 'changed' },
      { EXPO_PUBLIC_UNEXPECTED_KEY: 'secret' },
    ])
      assert.throws(
        () => assertPublicationSnapshot({ ...env, ...changed }, root),
        /configuration drift/,
      );
    writeFileSync(file, bytes + '\n');
    assert.throws(() => assertPublicationSnapshot(env, root), /Firebase/);
    writeFileSync(file, bytes);
    const output = join(root, '.ota/export');
    writeFileSync(
      join(output, 'metadata.json'),
      JSON.stringify({
        bundler: 'metro',
        fileMetadata: { android: { bundle: 'bundle.hbc' } },
      }),
    );
    writeFileSync(
      join(output, 'bundle.hbc'),
      Buffer.from('c61fbc03c103191f', 'hex'),
    );
    writeFileSync(
      join(output, 'bundle.hbc.map'),
      JSON.stringify({ sources: ['src/app.tsx'] }),
    );
    const exportHash = inspectOtaExport(output, {});
    sealPublicationSnapshot(env, root, exportHash);
    assert.equal(assertPublicationSnapshot(env, root).exportHash, exportHash);
    writeFileSync(join(output, 'bundle.hbc'), 'changed');
    assert.throws(() => assertPublicationSnapshot(env, root), /bundle drift/);
    assert.throws(
      () => sealPublicationSnapshot(env, root, exportHash),
      /bundle drift/,
    );
  } finally {
    assert.ok(root.startsWith(prefix));
    rmSync(root, { recursive: true, force: true });
  }
});
