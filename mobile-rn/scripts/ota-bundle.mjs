import { Buffer } from 'node:buffer';
import { readFileSync, readdirSync, lstatSync } from 'node:fs';
import { join, relative } from 'node:path';
import { hashBytes } from './ota-guards.mjs';
import { checkSources } from './check-runtime-bundle.mjs';

export function inspectOtaExport(root, env = process.env) {
  const files = [];
  const visit = (directory) => {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const file = join(directory, entry.name);
      if (lstatSync(file).isSymbolicLink())
        throw new Error('Symlinks are forbidden in OTA artifacts.');
      if (entry.isDirectory()) visit(file);
      else files.push(file);
    }
  };
  visit(root);
  const metadata = JSON.parse(
    readFileSync(join(root, 'metadata.json'), 'utf8'),
  );
  const bundle = metadata.fileMetadata?.android?.bundle;
  if (
    metadata.bundler !== 'metro' ||
    Object.keys(metadata.fileMetadata ?? {}).join(',') !== 'android' ||
    typeof bundle !== 'string' ||
    bundle.includes('..') ||
    bundle.startsWith('/') ||
    bundle.includes('\\')
  )
    throw new Error(
      'Expected a single Android Expo export with a safe bundle path.',
    );
  const bytecode = readFileSync(join(root, bundle));
  if (!bytecode.subarray(0, 8).equals(Buffer.from('c61fbc03c103191f', 'hex')))
    throw new Error(
      'Android OTA export must use the installed Hermes bytecode compiler.',
    );
  if (
    !files.some((file) => /metadata\.json$/.test(file)) ||
    !files.some((file) => /\.(?:hbc|js)$/.test(file))
  )
    throw new Error('Missing Expo export metadata or Hermes/JS bundle.');
  let maps = 0;
  const secrets = [
    'EXPO_TOKEN',
    'GITHUB_TOKEN',
    'ANDROID_KEYSTORE_PASSWORD',
    'ANDROID_KEY_PASSWORD',
  ]
    .map((name) => env[name])
    .filter((value) => value?.length > 8);
  const entries = files.sort().map((file) => {
    if (/(?:^|[\/\\])\.env|\.(?:jks|keystore|pem|p12|properties)$/.test(file))
      throw new Error('Signing or environment material in OTA artifact.');
    const bytes = readFileSync(file);
    if (secrets.some((value) => bytes.includes(Buffer.from(value))))
      throw new Error('A credential reached the OTA artifact.');
    if (file.endsWith('.map')) {
      const map = JSON.parse(bytes.toString('utf8'));
      if (!Array.isArray(map.sources) || !map.sources.length)
        throw new Error('Invalid OTA source map.');
      checkSources(map.sources);
      if (
        map.sources.some((source) => {
          const path = source.replaceAll('\\', '/');
          // Dependencies include legitimate runtime helpers in scripts/ (for
          // example Reanimated's native Worklets version check). Fixture-directory
          // checks apply to project code; test files remain forbidden everywhere.
          return (
            /\.(?:test|spec)\.[jt]sx?$/.test(path) ||
            (!/(?:^|\/)node_modules\//.test(path) &&
              /(?:^|\/)(?:visual|scripts|test-fixtures)\//.test(path))
          );
        })
      )
        throw new Error(
          'Fixture or test-only code reached the production bundle.',
        );
      maps++;
    }
    return [relative(root, file).replaceAll('\\', '/'), hashBytes(bytes)];
  });
  if (!maps)
    throw new Error('Production export needs source maps for validation.');
  return hashBytes(JSON.stringify(entries));
}
