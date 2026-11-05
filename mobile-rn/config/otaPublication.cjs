'use strict';
const { createHash } = require('node:crypto');
const {
  existsSync,
  lstatSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} = require('node:fs');
const { join, relative } = require('node:path');
const { productionEnvironmentConfig } = require('./productionEnvironment.cjs');

const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
const snapshotPath = (root) => join(root, '.ota/publication-snapshot.json');

function configurationDigest(env) {
  // Include absent/present changes, extra public variables and Firebase base64.
  // Persist only a digest, never SDK keys, client JSON, or signing inputs.
  return digest(JSON.stringify(configurationFields(env)));
}

function configurationFields(env) {
  return Object.fromEntries(
    Object.keys(env)
      .filter(
        (name) =>
          /^(?:APP_|ANDROID_|EXPO_PUBLIC_|EXPO_UPDATES_|GOOGLE_|IOS_)/.test(
            name,
          ) || ['EXPO_NO_DOTENV', 'EAS_BUILD_CHANNEL'].includes(name),
      )
      .sort()
      .map((name) => [name, digest(String(env[name]))]),
  );
}

function exportDigest(directory) {
  const files = [];
  const visit = (path) => {
    for (const entry of readdirSync(path, { withFileTypes: true })) {
      const file = join(path, entry.name);
      if (lstatSync(file).isSymbolicLink())
        throw new Error('Symlink in publication export.');
      if (entry.isDirectory()) visit(file);
      else files.push(file);
    }
  };
  visit(directory);
  return digest(
    JSON.stringify(
      files
        .sort()
        .map((file) => [
          relative(directory, file).replaceAll('\\', '/'),
          digest(readFileSync(file)),
        ]),
    ),
  );
}

function createPublicationSnapshot(
  env,
  root,
  { runtimeVersion, environmentHash },
) {
  const shared = productionEnvironmentConfig(env, root);
  if (
    env.APP_CONFIG_MODE !== 'ota' ||
    env.EXPO_UPDATES_CHANNEL !== 'staging' ||
    shared.environmentHash !== environmentHash ||
    !/^[a-f0-9]{40}$/.test(runtimeVersion)
  )
    throw new Error('Invalid staging publication snapshot.');
  const snapshot = {
    schemaVersion: 1,
    environment: 'production',
    runtimeVersion,
    environmentHash,
    configurationDigest: configurationDigest(env),
    configurationFields: configurationFields(env),
    firebaseDigest: digest(readFileSync(shared.googleServicesFile)),
  };
  writeFileSync(snapshotPath(root), JSON.stringify(snapshot) + '\n', {
    flag: 'wx',
    mode: 0o600,
  });
  return snapshot;
}

function assertPublicationSnapshot(env, root) {
  const file = snapshotPath(root);
  if (!existsSync(file)) return;
  if (lstatSync(file).isSymbolicLink())
    throw new Error('Publication snapshot cannot be a symlink.');
  const snapshot = JSON.parse(readFileSync(file, 'utf8'));
  if (
    snapshot.schemaVersion !== 1 ||
    snapshot.environment !== 'production' ||
    configurationDigest(env) !== snapshot.configurationDigest
  ) {
    const current = configurationFields(env);
    const changed = [
      ...new Set([
        ...Object.keys(current),
        ...Object.keys(snapshot.configurationFields ?? {}),
      ]),
    ].filter((name) => current[name] !== snapshot.configurationFields?.[name]);
    throw new Error(
      `OTA publication configuration drift: ${changed.join(', ') || 'invalid snapshot'}. EAS environment differs from the validated export.`,
    );
  }
  const shared = productionEnvironmentConfig(env, root);
  if (
    shared.environmentHash !== snapshot.environmentHash ||
    digest(readFileSync(shared.googleServicesFile)) !== snapshot.firebaseDigest
  )
    throw new Error('OTA publication Firebase or public environment drift.');
  if (
    snapshot.exportHash &&
    exportDigest(join(root, '.ota/export')) !== snapshot.exportHash
  )
    throw new Error(
      'OTA publication bundle drift: export changed after validation.',
    );
  return snapshot;
}

function sealPublicationSnapshot(env, root, exportHash) {
  const snapshot = assertPublicationSnapshot(env, root);
  if (
    !snapshot ||
    !/^[a-f0-9]{64}$/.test(exportHash) ||
    exportDigest(join(root, '.ota/export')) !== exportHash
  )
    throw new Error('Cannot seal a missing or changed OTA publication export.');
  writeFileSync(
    snapshotPath(root),
    JSON.stringify({ ...snapshot, exportHash }) + '\n',
    { mode: 0o600 },
  );
}

module.exports = {
  createPublicationSnapshot,
  assertPublicationSnapshot,
  sealPublicationSnapshot,
  snapshotPath,
};
