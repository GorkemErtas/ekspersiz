import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export async function nativeFingerprint(root = process.cwd()) {
  if (
    execFileSync('git', ['ls-files', '--', 'android/', 'ios/'], {
      cwd: root,
      encoding: 'utf8',
    }).trim()
  )
    throw new Error(
      'Tracked native projects require manual review; this pipeline uses managed/CNG native inputs.',
    );
  const require = createRequire(resolve(root, 'package.json'));
  const { resolveRuntimeVersionAsync } = require(
    join(
      dirname(require.resolve('expo-updates/package.json')),
      'utils/build/resolveRuntimeVersionAsync.js',
    ),
  );
  // Use the same policy resolver as EAS Update, including its CNG native ignores.
  const { runtimeVersion, fingerprintSources: sources } =
    await resolveRuntimeVersionAsync(
      root,
      'android',
      { silent: true },
      { workflowOverride: 'managed' },
    );
  if (!/^[0-9a-f]{40}$/.test(runtimeVersion) || !sources?.length)
    throw new Error('Native fingerprint could not be determined.');
  for (const id of [
    'expoConfig',
    'expoAutolinkingConfig:android',
    'rncoreAutolinkingConfig:android',
  ]) {
    if (!sources.some((source) => source.id === id && source.hash))
      throw new Error(
        `Incomplete native fingerprint: ${id}. Autolinking must succeed.`,
      );
  }
  for (const filePath of ['modules', 'src/platform']) {
    if (!sources.some((source) => source.filePath === filePath && source.hash))
      throw new Error(
        `Native bridge contract is missing from fingerprint: ${filePath}.`,
      );
  }
  return runtimeVersion;
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
