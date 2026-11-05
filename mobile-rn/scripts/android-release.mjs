import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseEnv } from 'node:util';
import { productionEnvironmentConfig } from '../config/productionEnvironment.cjs';
import { inspectApk, verifyNativeOta } from './ota-inspect-binary.mjs';
import {
  androidReleaseConfig,
  releaseEnvironmentNames,
} from '../config/androidRelease.cjs';
import {
  checkManifest,
  checkSplashResources,
} from './check-android-manifest.mjs';
import { checkAndroidR8 } from './check-android-r8.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const envFile = resolve(
  root,
  process.argv.slice(2).find((value) => !value.startsWith('--')) ??
    '.env.production.local',
);
const checkOnly = process.argv.includes('--check');
const withApk = process.argv.includes('--apk');
const env = { ...process.env };
// Expo/Metro must not inherit public values from the current development shell.
for (const name of Object.keys(env))
  if (name.startsWith('EXPO_PUBLIC_') || releaseEnvironmentNames.has(name))
    delete env[name];
let values;
try {
  values = parseEnv(readFileSync(envFile, 'utf8'));
} catch {
  throw new Error(
    'Create the ignored .env.production.local from .env.example and the release guide first.',
  );
}
for (const name of Object.keys(values)) {
  if (!releaseEnvironmentNames.has(name))
    throw new Error(
      `Unrecognized release environment name: ${name}. No service secrets belong in this file.`,
    );
}
if (values.APP_VARIANT !== 'production')
  throw new Error(
    'The explicit release environment file must set APP_VARIANT=production.',
  );
if (values.APP_CONFIG_MODE && values.APP_CONFIG_MODE !== 'native')
  throw new Error('Native release environment cannot use APP_CONFIG_MODE=ota.');
Object.assign(env, values, {
  APP_VARIANT: 'production',
  EXPO_NO_DOTENV: '1',
  APP_CONFIG_MODE: 'native',
});
const config = androidReleaseConfig(env, root);
Object.assign(env, {
  ANDROID_KEYSTORE_PROPERTIES_FILE: config.signingPropertiesFile,
  ANDROID_KEYSTORE_BASE_DIR: config.signingBaseDirectory,
  GOOGLE_SERVICES_FILE: config.googleServicesFile,
});
const java = env.JAVA_HOME
  ? join(
      env.JAVA_HOME,
      'bin',
      process.platform === 'win32' ? 'java.exe' : 'java',
    )
  : 'java';
const identitySource = join(root, 'scripts/android/ReleaseIdentity.java');
function identity(artifact) {
  const result = spawnSync(
    java,
    [
      identitySource,
      'signing',
      config.signingPropertiesFile,
      config.signingBaseDirectory,
      ...(artifact ? [artifact] : []),
    ],
    { env, encoding: 'utf8' },
  );
  if (result.status !== 0)
    throw new Error(
      `Release signing/artifact verification failed. ${result.stderr?.trim() ?? 'Check Java 21 and existing key.properties/keystore.'}`,
    );
  return JSON.parse(result.stdout);
}
function run(command, args, cwd = root) {
  const batch = process.platform === 'win32' && command.endsWith('.bat');
  if (
    batch &&
    (command !== 'gradlew.bat' ||
      args.some((arg) => !/^[-A-Za-z0-9_:.,=/]+$/.test(arg)))
  )
    throw new Error(
      'Only fixed, shell-safe Gradle wrapper arguments are permitted.',
    );
  const result = spawnSync(
    batch ? (env.ComSpec ?? 'cmd.exe') : command,
    batch ? ['/d', '/c', command, ...args] : args,
    {
      cwd,
      env,
      stdio: 'inherit',
    },
  );
  if (result.status !== 0)
    throw new Error(
      `Release command failed: ${command}. See the preceding build output.`,
    );
}
let otaRuntime;
if (env.EXPO_UPDATES_ENABLED === '1') {
  if (!checkOnly && !withApk)
    throw new Error(
      'OTA-enabled native releases require --apk for compiled update metadata verification.',
    );
  const result = spawnSync(process.execPath, ['scripts/ota-fingerprint.mjs'], {
    cwd: root,
    env,
    encoding: 'utf8',
    timeout: 120000,
  });
  if (result.status !== 0 || !/^[a-f0-9]{40}$/.test(result.stdout.trim()))
    throw new Error('Production native OTA fingerprint validation failed.');
  otaRuntime = result.stdout.trim();
}
const signer = identity();
console.log(
  'Production inputs, Firebase package/web OAuth/Play SHA-1, increasing versionCode and existing private upload key verified locally.',
);
if (checkOnly) {
  console.log(
    'Preflight only. Console restrictions, backend Integrity settings and physical-device flows still require the release checklist.',
  );
} else {
  run(process.execPath, [
    'node_modules/expo/bin/cli',
    'prebuild',
    '--platform',
    'android',
    '--no-install',
  ]);
  const wrapper = process.platform === 'win32' ? 'gradlew.bat' : './gradlew';
  // Preserve Flutter's release ABIs, including existing 32-bit ARM devices.
  run(
    wrapper,
    [
      ':app:bundleRelease',
      ...(withApk ? [':app:assembleRelease'] : []),
      ':app:lintRelease',
      '-PreactNativeArchitectures=armeabi-v7a,arm64-v8a,x86_64',
      '--max-workers=2',
      '--no-daemon',
    ],
    join(root, 'android'),
  );
  const manifest = readFileSync(
    join(
      root,
      'android/app/build/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml',
    ),
    'utf8',
  );
  checkManifest(manifest, {
    release: true,
    production: true,
    versionCode: config.versionCode,
    versionName: config.versionName,
  });
  checkSplashResources(
    readFileSync(
      join(root, 'android/app/src/main/res/values/styles.xml'),
      'utf8',
    ),
    readFileSync(
      join(root, 'android/app/src/main/res/values-v33/styles.xml'),
      'utf8',
    ),
  );
  run(process.execPath, [
    'scripts/check-runtime-bundle.mjs',
    'android/app/build/generated/sourcemaps/react/release',
  ]);
  const artifact = join(
    root,
    'android/app/build/outputs/bundle/release/app-release.aab',
  );
  const r8 = checkAndroidR8(join(root, 'android'));
  const verified = identity(artifact);
  if (
    verified.sha256 !== signer.sha256 ||
    !verified.arm64 ||
    !verified.arm32 ||
    !verified.x64
  )
    throw new Error(
      'Release signer changed during build or an existing Flutter ABI is missing.',
    );
  const output = join(root, 'release-artifacts');
  mkdirSync(output, { recursive: true });
  const name = `ekspersiz-${config.versionName}-${config.versionCode}`;
  const destination = join(output, `${name}.aab`);
  let apk;
  if (withApk) {
    const path = join(
      root,
      'android/app/build/outputs/apk/release/app-release.apk',
    );
    const result = spawnSync(java, [identitySource, 'constructors', path], {
      env,
      encoding: 'utf8',
    });
    if (result.status !== 0)
      throw new Error(`APK constructor verification failed: ${result.stderr}`);
    const constructors = JSON.parse(result.stdout);
    if (
      JSON.stringify(constructors.dexSha256) !==
      JSON.stringify(verified.constructors.dexSha256)
    )
      throw new Error(
        'Optimized APK and AAB DEX hashes differ. Do not use this APK as release startup evidence.',
      );
    const sdk = env.ANDROID_HOME ?? env.ANDROID_SDK_ROOT;
    if (!sdk)
      throw new Error(
        'ANDROID_HOME is required for APK signature verification.',
      );
    const signature = spawnSync(
      java,
      [
        '-jar',
        join(sdk, 'build-tools/37.0.0/lib/apksigner.jar'),
        'verify',
        '--verbose',
        '--print-certs',
        path,
      ],
      { env, encoding: 'utf8' },
    );
    if (
      signature.status !== 0 ||
      !signature.stdout
        .toUpperCase()
        .includes(`CERTIFICATE SHA-256 DIGEST: ${signer.sha256}`)
    )
      throw new Error(
        'Optimized APK signature does not match the existing Flutter upload key.',
      );
    copyFileSync(path, join(output, `${name}.apk`));
    let ota;
    if (otaRuntime) {
      ota = verifyNativeOta(inspectApk(path, { env }), {
        channel: env.EXPO_UPDATES_CHANNEL,
        runtimeVersion: otaRuntime,
      });
      ota.environmentHash = productionEnvironmentConfig(
        env,
        root,
      ).environmentHash;
      ota.sourceCommit = spawnSync('git', ['rev-parse', 'HEAD'], {
        cwd: root,
        encoding: 'utf8',
      }).stdout.trim();
    }
    apk = {
      ...(ota ? { ota } : {}),
      sha256: createHash('sha256').update(readFileSync(path)).digest('hex'),
      uploadCertificate: signer.sha256,
      dexMatchesAab: true,
    };
  }
  copyFileSync(artifact, destination);
  copyFileSync(
    join(root, 'android/app/build/outputs/mapping/release/mapping.txt'),
    join(output, `${name}-mapping.txt`),
  );
  writeFileSync(
    join(output, `${name}-verification.json`),
    JSON.stringify(
      {
        package: 'com.gorkem.ekspersiz',
        versionName: config.versionName,
        versionCode: config.versionCode,
        sha256: createHash('sha256')
          .update(readFileSync(destination))
          .digest('hex'),
        uploadCertificate: verified.sha256,
        playAppSigningCertificate: config.sha256,
        native: verified,
        r8,
        ...(apk ? { apk } : {}),
        builtAt: new Date().toISOString(),
        manualDeviceAndConsoleChecksRequired: true,
      },
      null,
      2,
    ) + '\n',
  );
  console.log(`Signed production AAB verified: release-artifacts/${name}.aab`);
  console.log(
    'Complete the physical-device and console checks in docs/production/ANDROID_RELEASE.md before rollout.',
  );
}
