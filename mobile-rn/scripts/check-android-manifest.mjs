import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function checkManifest(
  xml,
  { release = false, production = false, versionCode, versionName } = {},
) {
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
  if (release) {
    for (const initializer of [
      'androidx.startup.InitializationProvider',
      'androidx.work.WorkManagerInitializer',
    ])
      assert.ok(
        xml.includes(`android:name="${initializer}"`),
        `Required release startup component missing: ${initializer}`,
      );
    const application = xml.match(/<application\b[^>]*>/s)?.[0];
    assert.ok(application, 'Application missing from merged release manifest');
    assert.ok(
      !application.includes('android:debuggable="true"'),
      'Release application is debuggable',
    );
    assert.ok(
      !xml.includes('DevLauncherActivity'),
      'Development launcher leaked into release',
    );
    assert.ok(
      !permissions.has('android.permission.SYSTEM_ALERT_WINDOW'),
      'Development overlay permission leaked into release',
    );
    if (production) {
      const manifest = xml.match(/<manifest\b[^>]*>/s)?.[0] ?? '';
      assert.match(
        manifest,
        /package="com\.gorkem\.ekspersiz"/,
        'Production must update the existing Play package',
      );
      assert.ok(
        application.includes('android:usesCleartextTraffic="false"'),
        'Production cleartext traffic must be disabled',
      );
      assert.ok(
        application.includes('android:allowBackup="false"'),
        'Production private application backup must be disabled',
      );
      assert.ok(
        xml.includes('com.google.firebase.MESSAGING_EVENT'),
        'Production FCM service missing',
      );
      assert.ok(
        [...xml.matchAll(/<meta-data\b[^>]*>/g)].some(
          ([entry]) =>
            entry.includes(
              'android:name="firebase_messaging_auto_init_enabled"',
            ) && entry.includes('android:value="false"'),
        ),
        'Production FCM must remain disabled until authenticated registration',
      );
      assert.ok(
        xml.includes('com.google.android.geo.API_KEY'),
        'Production Maps configuration missing',
      );
      assert.ok(
        !xml.includes('ekspersiz-dev') && !xml.includes('exp+ekspersiz'),
        'Development URL scheme leaked into production',
      );
      if (versionCode !== undefined)
        assert.ok(
          manifest.includes(`android:versionCode="${versionCode}"`),
          'Production manifest versionCode differs from the verified release input',
        );
      if (versionName !== undefined)
        assert.ok(
          manifest.includes(`android:versionName="${versionName}"`),
          'Production manifest versionName differs from the verified release input',
        );
    }
  }
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
  checkManifest(readFileSync(path, 'utf8'), {
    release: process.argv.includes('--release'),
  });
  checkSplashResources(
    readFileSync('android/app/src/main/res/values/styles.xml', 'utf8'),
    readFileSync('android/app/src/main/res/values-v33/styles.xml', 'utf8'),
  );
  console.log(
    'Merged Android manifest: camera, speech, location, FCM and billing present; broad storage/media absent.',
  );
}
