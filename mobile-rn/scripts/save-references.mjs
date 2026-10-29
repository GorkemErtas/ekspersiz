import { createHash } from 'node:crypto';
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PNG } from 'pngjs';

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../..',
);
const target = path.join(root, 'docs/migration/reference');
await mkdir(target, { recursive: true });
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
const manifest = {
  provenance:
    'Real Flutter auth widgets; original Inter Regular/Medium assets and original Material icon font. No RN render used as a reference.',
  date: '2026-10-29',
  logicalViewport: { width: 390, height: 844 },
  devicePixelRatio: 1,
  fontScale: 1,
  safeArea: { top: 0, bottom: 0, left: 0, right: 0 },
  keyboardPixels: false,
  reducedMotion: true,
  nativeComparisonAccepted: false,
  assets: [],
  captures: [],
};
for (const name of ['Inter-Regular.ttf', 'Inter-Medium.ttf']) {
  const original = await readFile(path.join(root, 'mobile/assets/fonts', name));
  const migrated = await readFile(
    path.join(root, 'mobile-rn/assets/fonts', name),
  );
  if (!original.equals(migrated))
    throw new Error(`Font asset differs: ${name}`);
  manifest.assets.push({
    path: `mobile/assets/fonts/${name}`,
    sha256: hash(original),
  });
}
for (const screen of ['login', 'register', 'forgot-password', 'verify-email']) {
  for (const theme of ['dark', 'light']) {
    const name = `${screen}-${theme}-phone.png`;
    const source = path.join(root, 'mobile-rn/visual-artifacts/flutter', name);
    const bytes = await readFile(source);
    const png = PNG.sync.read(bytes);
    if (png.width !== 390 || png.height !== 844)
      throw new Error(`Unexpected viewport: ${name}`);
    await copyFile(source, path.join(target, name));
    manifest.captures.push({ screen, theme, file: name, sha256: hash(bytes) });
  }
}
await writeFile(
  path.join(target, 'manifest.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
);
console.log(
  'Saved eight Flutter phone references and verified the original font hashes.',
);
