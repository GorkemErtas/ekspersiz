import { createHash } from 'node:crypto';
import { readdir, readFile, mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../..',
);
async function files(directory) {
  const result = [];
  for (const entry of await readdir(path.join(root, directory), {
    withFileTypes: true,
  })) {
    const name = `${directory}/${entry.name}`;
    if (entry.isDirectory()) result.push(...(await files(name)));
    else result.push(name);
  }
  return result.sort();
}
const source = await files('mobile/lib');
const tests = await files('mobile/test');
const controllers = (
  await files('src/main/java/com/gorkem/vehicle_inspector/controller')
).filter((name) => !/Internal|Webhook/.test(name));
const dtos = await files('src/main/java/com/gorkem/vehicle_inspector/dto');
const records = [];
for (const name of [...source, ...tests, ...controllers, ...dtos]) {
  const content = await readFile(path.join(root, name), 'utf8');
  records.push({
    path: name,
    sha256: createHash('sha256').update(content).digest('hex'),
    lines: content.split('\n').length,
    ...(name.includes('/screens/')
      ? {
          navigation: [
            ...content.matchAll(
              /(?:push|pushReplacement|pushAndRemoveUntil|builder|screen):?\s*\(?[^\n]*/g,
            ),
          ].map((match) => match[0]),
        }
      : {}),
    ...(name.includes('/services/') || name.includes('/controller/')
      ? {
          contractLines: content
            .split('\n')
            .flatMap((line, i) =>
              /apiClient\.|_apiClient\.|@(?:Request|Get|Post|Put|Delete|Patch)Mapping|fileFieldName:|timeout:/.test(
                line,
              )
                ? [{ line: i + 1, text: line.trim() }]
                : [],
            ),
        }
      : {}),
  });
}
const output = {
  generatedFrom:
    'Working tree; regenerate after Flutter changes. Hashes are source provenance, not a claim of parity.',
  screens: source.filter((name) => name.includes('/screens/')),
  models: source.filter((name) => name.includes('/models/')),
  services: source.filter((name) => name.includes('/services/')),
  backendDtos: dtos,
  tests,
  records,
};
await mkdir(path.join(root, 'docs/migration'), { recursive: true });
await writeFile(
  path.join(root, 'docs/migration/flutter-inventory.json'),
  `${JSON.stringify(output, null, 2)}\n`,
);
console.log(
  `Inventoried ${output.screens.length} screens, ${output.models.length} models, ${output.services.length} services, ${tests.length} test files.`,
);
