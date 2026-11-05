import { execFileSync } from 'node:child_process';
import { appendFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { pathToFileURL } from 'node:url';

export function classifyChanges(paths) {
  const native = [],
    ota = [],
    ignored = [];
  for (const original of paths) {
    const file = original.replaceAll('\\', '/');
    if (/(^|\/)\.\.(\/|$)/.test(file) || file.startsWith('/'))
      throw new Error('Unsafe change path.');
    if (
      /^mobile-rn\/(?:src|app|scripts)\/.*\.(?:test|spec)\.[cm]?[jt]sx?$/.test(
        file,
      ) ||
      file === 'mobile-rn/scripts/ota-fixtures.mjs' ||
      /^docs\//.test(file) ||
      /(?:^|\/)README\.md$/.test(file)
    )
      ignored.push(file);
    else if (
      /^mobile-rn\/src\/platform\//.test(file) ||
      file === 'mobile-rn/assets/images/ekspersiz_logo.png'
    )
      native.push(file);
    else if (
      /^mobile-rn\/(?:src|app)\/.*\.[jt]sx?$/.test(file) ||
      /^mobile-rn\/assets\/(?:guide|images)\/.*\.(?:png|jpe?g|webp|gif)$/.test(
        file,
      )
    )
      ota.push(file);
    else if (
      file.startsWith('mobile-rn/') ||
      file.startsWith('.github/workflows/') ||
      file === '.gitattributes'
    )
      native.push(file);
    else ignored.push(file);
  }
  return {
    kind: native.length ? 'native' : ota.length ? 'ota' : 'none',
    native,
    ota,
    ignored,
    explanation: native.length
      ? 'Native or unclassified inputs changed. Review the fingerprint and use the validated native release process when required; automatic OTA is blocked.'
      : ota.length
        ? 'OTA candidate; fingerprint, environment, approved binary and validation gates must also pass.'
        : 'No runtime mobile changes.',
  };
}
export function changedPaths(base, head = 'HEAD', cwd = process.cwd()) {
  for (const ref of [base, head])
    if (!/^(?:[0-9a-f]{40}|HEAD)$/.test(ref))
      throw new Error(
        'Use a complete commit SHA, not an arbitrary Git expression.',
      );
  if (/^0{40}$/.test(base))
    throw new Error(
      'Initial-push baseline is unknown; manual native review required.',
    );
  // --no-renames exposes both sides of a rename, including removed native files.
  return execFileSync(
    'git',
    ['diff', '--name-only', '--no-renames', '-z', base, head],
    { cwd, encoding: 'utf8' },
  )
    .split('\0')
    .filter(Boolean);
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const base = process.env.OTA_BASE_SHA,
    head = process.env.OTA_HEAD_SHA ?? 'HEAD';
  const result = classifyChanges(changedPaths(base, head));
  const report =
    process.env.OTA_CLASSIFICATION_REPORT ??
    'mobile-rn/.ota/classification.json';
  mkdirSync(dirname(report), { recursive: true });
  writeFileSync(report, JSON.stringify(result, null, 2) + '\n');
  if (process.env.GITHUB_OUTPUT)
    appendFileSync(process.env.GITHUB_OUTPUT, `kind=${result.kind}\n`);
  if (process.env.GITHUB_STEP_SUMMARY)
    appendFileSync(
      process.env.GITHUB_STEP_SUMMARY,
      `### Mobile update classification: ${result.kind}\n\n${result.explanation}\n\n${result.native.map((file) => '- `' + file.replaceAll('`', '') + '`').join('\n')}\n`,
    );
  console.log(JSON.stringify(result, null, 2));
}
