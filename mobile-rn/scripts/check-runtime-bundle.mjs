import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

export function checkSources(sources) {
  const forbidden = /(?:^|\/)node_modules\/(?:zod|deepmerge)(?:\/|$)/;
  const matches = sources.filter((source) => {
    const path = source.replaceAll('\\', '/');
    // Expo intentionally ships this standalone Metro module loader. It does
    // not import the CLI's schema/config tooling or either vulnerable package.
    const cli = /(?:^|\/)node_modules\/@expo\/cli\//.test(path);
    return (
      forbidden.test(path) ||
      (cli && !path.endsWith('/@expo/cli/build/metro-require/require.js'))
    );
  });
  if (matches.length)
    throw new Error(
      `Tooling advisory reached the runtime bundle: ${matches.join(', ')}`,
    );
}
function walk(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) =>
    entry.isDirectory()
      ? walk(join(directory, entry.name))
      : [join(directory, entry.name)],
  );
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const maps = walk(process.argv[2] ?? 'dist').filter((file) =>
    file.endsWith('.map'),
  );
  if (!maps.length)
    throw new Error('No source maps found; runtime exposure was not verified.');
  for (const file of maps) {
    const map = JSON.parse(readFileSync(file, 'utf8'));
    if (!Array.isArray(map.sources) || !map.sources.length)
      throw new Error(`Invalid source map: ${file}`);
    checkSources(map.sources);
    console.log(
      `${file}: ${map.sources.length} sources; no accepted tooling advisory in runtime.`,
    );
  }
}
