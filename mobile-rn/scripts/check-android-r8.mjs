import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

export function checkConstructorRules(rules) {
  rules = rules.replace(/#.*/g, '');
  for (const parent of [
    'androidx.room.RoomDatabase',
    'androidx.work.InputMerger',
  ]) {
    const escaped = parent.replaceAll('.', '\\.');
    assert.match(
      rules,
      new RegExp(
        `-keep\\s+class\\s+\\*\\s+extends\\s+${escaped}\\s*\\{\\s*<init>\\(\\);\\s*\\}`,
      ),
      `Missing explicit no-arg constructor keep rule for ${parent}`,
    );
  }
}

export function checkAndroidR8(root = 'android') {
  checkConstructorRules(
    readFileSync(join(root, 'app/proguard-rules.pro'), 'utf8'),
  );
  const properties = readFileSync(join(root, 'gradle.properties'), 'utf8');
  for (const property of [
    'android.enableMinifyInReleaseBuilds',
    'android.enableShrinkResourcesInReleaseBuilds',
    'hermesEnabled',
  ])
    assert.match(
      properties,
      new RegExp(`^${property.replaceAll('.', '\\.')}=true$`, 'm'),
    );
  assert.doesNotMatch(properties, /^android\.enableR8\.fullMode=false$/m);
  assert.match(
    readFileSync(join(root, 'app/build.gradle'), 'utf8'),
    /proguard-android-optimize\.txt/,
  );
  // Check R8's effective inputs too, after dependency consumer rules are merged.
  checkConstructorRules(
    readFileSync(
      join(root, 'app/build/outputs/mapping/release/configuration.txt'),
      'utf8',
    ),
  );
  return {
    generatedRules: true,
    effectiveR8Rules: true,
    minify: true,
    shrinkResources: true,
    hermes: true,
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
  console.log(JSON.stringify(checkAndroidR8(process.argv[2])));
