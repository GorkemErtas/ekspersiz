import { readFile, writeFile, copyFile, mkdir } from 'node:fs/promises';
const catalog = await readFile(
  '../mobile/lib/features/vehicle/models/vehicle_catalog.dart',
  'utf8',
);
const literal = catalog.slice(
  catalog.indexOf('brandModels = {') + 'brandModels = '.length,
  catalog.indexOf('};') + 1,
);
// The Flutter catalog is a constant string/list map, not executable Dart.
const pairs = [...literal.matchAll(/'([^']+)':\s*\[([^\]]+)\]/g)].map(
  ([, brand, models]) => [
    brand,
    [...models.matchAll(/'([^']+)'/g)].map((m) => m[1]),
  ],
);
await mkdir('src/features/vehicle', { recursive: true });
await writeFile(
  'src/features/vehicle/catalog.ts',
  `// Source: Flutter VehicleCatalog; no vehicle data is invented.\nexport const vehicleCatalog: Record<string, string[]> = ${JSON.stringify(Object.fromEntries(pairs), null, 2)};\n`,
);
for (const name of ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'LICENSE.txt'])
  await copyFile(`../mobile/assets/fonts/${name}`, `assets/fonts/${name}`);
const labels = await readFile(
  '../mobile/lib/features/inspection/models/inspection_labels.dart',
  'utf8',
);
await writeFile(
  'src/core/inspectionLabels.ts',
  `// Source: Flutter InspectionLabels, including historical records.\nexport const inspectionLabels: Record<string,string> = ${JSON.stringify(Object.fromEntries([...labels.matchAll(/'([^']+)':\s*'([^']+)'/g)].map(([, key, value]) => [key, value])), null, 2)};\n`,
);
const guide = await readFile(
  '../mobile/lib/features/onboarding/models/onboarding_step.dart',
  'utf8',
);
const steps = [
  ...guide.matchAll(
    /OnboardingStep\(\s*feature:\s*GuideFeature\.(\w+),([\s\S]*?)\),/g,
  ),
].map(([, feature, body]) =>
  Object.fromEntries([
    ['feature', feature],
    ...['category', 'title', 'description', 'hint'].map((key) => [
      key,
      [
        ...(
          body.match(new RegExp(`${key}:\\s*((?:'[^']*'\\s*)+),`))?.[1] ?? ''
        ).matchAll(/'([^']*)'/g),
      ]
        .map((match) => match[1])
        .join('')
        .replaceAll('\\n', '\n'),
    ]),
  ]),
);
await mkdir('src/features/onboarding', { recursive: true });
await writeFile(
  'src/features/onboarding/steps.ts',
  `// Original Flutter onboarding copy.\nexport const steps=${JSON.stringify(steps, null, 2)};\n`,
);
