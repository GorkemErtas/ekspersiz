import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function checkManifest(xml) {
  const permissions = new Set(
    [...xml.matchAll(/<uses-permission\b[^>]*android:name="([^"]+)"[^>]*>/g)]
      .filter(([entry]) => !entry.includes('tools:node="remove"'))
      .map(([, name]) => name),
  );
  for (const name of [
    'CAMERA',
    'RECORD_AUDIO',
    'POST_NOTIFICATIONS',
    'INTERNET',
    'ACCESS_FINE_LOCATION',
    'ACCESS_COARSE_LOCATION',
  ])
    assert.ok(
      permissions.has(`android.permission.${name}`),
      `Required native permission missing: ${name}`,
    );
  assert.ok(
    permissions.has('com.android.vending.BILLING'),
    'Billing permission missing',
  );
  for (const name of [
    'READ_EXTERNAL_STORAGE',
    'WRITE_EXTERNAL_STORAGE',
    'READ_MEDIA_IMAGES',
    'READ_MEDIA_VIDEO',
    'READ_MEDIA_VISUAL_USER_SELECTED',
  ])
    assert.ok(
      !permissions.has(`android.permission.${name}`),
      `Broad storage/media permission present: ${name}`,
    );
}
export function checkSplashResources(base, api33) {
  assert.ok(
    !base.includes('android:windowSplashScreenBehavior'),
    'API 33 splash attribute leaked to older Android versions',
  );
  for (const name of [
    'windowSplashScreenBackground',
    'windowSplashScreenAnimatedIcon',
    'postSplashScreenTheme',
  ]) {
    assert.ok(
      base.includes(`name="${name}"`),
      `Base splash item missing: ${name}`,
    );
    assert.ok(
      api33.includes(`name="${name}"`),
      `API 33 splash item missing: ${name}`,
    );
  }
  assert.ok(
    api33.includes('name="android:windowSplashScreenBehavior"'),
    'API 33 splash behavior missing',
  );
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const path =
    process.argv[2] ??
    'android/app/build/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml';
  checkManifest(readFileSync(path, 'utf8'));
  checkSplashResources(
    readFileSync('android/app/src/main/res/values/styles.xml', 'utf8'),
    readFileSync('android/app/src/main/res/values-v33/styles.xml', 'utf8'),
  );
  console.log(
    'Merged Android manifest: camera, speech, location, FCM and billing present; broad storage/media absent.',
  );
}
