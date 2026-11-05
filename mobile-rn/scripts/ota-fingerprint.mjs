import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export async function nativeFingerprint(root = process.cwd()) {
  const require = createRequire(resolve(root, 'package.json'));
  const { createFingerprintAsync } = require('expo/fingerprint');
  // Match expo-updates' managed/CNG runtime resolver, before or after prebuild.
  const fingerprint = await createFingerprintAsync(root, {
    platforms: ['android'],
    ignorePaths: ['android/**/*', 'ios/**/*'],
    silent: true,
  });
  if (!/^[0-9a-f]{40}$/.test(fingerprint.hash) || !fingerprint.sources.length)
    throw new Error('Native fingerprint could not be determined.');
  for (const id of [
    'expoConfig',
    'expoAutolinkingConfig:android',
    'rncoreAutolinkingConfig:android',
  ]) {
    if (!fingerprint.sources.some((source) => source.id === id && source.hash))
      throw new Error(
        `Incomplete native fingerprint: ${id}. Autolinking must succeed.`,
      );
  }
  for (const filePath of ['modules', 'src/platform']) {
    if (
      !fingerprint.sources.some(
        (source) => source.filePath === filePath && source.hash,
      )
    )
      throw new Error(
        `Native bridge contract is missing from fingerprint: ${filePath}.`,
      );
  }
  return fingerprint.hash;
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const head = await nativeFingerprint(resolve(process.argv[2] ?? '.'));
  if (process.argv[3]) {
    const base = await nativeFingerprint(resolve(process.argv[3]));
    if (head !== base)
      throw new Error(
        'Native fingerprints differ; a compatible native build and review are required.',
      );
  }
  console.log(head);
}
