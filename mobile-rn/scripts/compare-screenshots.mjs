import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

// No resizing, cropping, translation, or baselines generated from the RN image.
const [referencePath, nativePath, outputPath, maxMismatchArg = '0.01'] =
  process.argv.slice(2);
if (!referencePath || !nativePath || !outputPath) {
  console.error(
    'Usage: npm run visual:compare -- reference.png native.png diff.png [maximum-mismatch-fraction=0.01]',
  );
  process.exit(2);
}
const maximum = Number(maxMismatchArg);
if (!Number.isFinite(maximum) || maximum < 0 || maximum > 1)
  throw new Error('Mismatch limit must be between 0 and 1.');
const reference = PNG.sync.read(readFileSync(referencePath));
const native = PNG.sync.read(readFileSync(nativePath));
if (reference.width !== native.width || reference.height !== native.height) {
  throw new Error(
    `Equivalent viewport required: reference ${reference.width}×${reference.height}; native ${native.width}×${native.height}.`,
  );
}
const diff = new PNG({ width: reference.width, height: reference.height });
const mismatchedPixels = pixelmatch(
  reference.data,
  native.data,
  diff.data,
  reference.width,
  reference.height,
  { threshold: 0.1, includeAA: false },
);
const fraction = mismatchedPixels / (reference.width * reference.height);
mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, PNG.sync.write(diff));
const report = {
  referencePath,
  nativePath,
  width: reference.width,
  height: reference.height,
  mismatchedPixels,
  fraction,
  maximum,
  passed: fraction <= maximum,
  review:
    'A numeric pass still requires human review of typography, layout, state, motion, accessibility, and native-device behavior.',
};
writeFileSync(`${outputPath}.json`, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));
if (!report.passed) process.exitCode = 1;
