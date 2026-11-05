import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import {
  easProject,
  productionPackage,
} from '../config/productionEnvironment.cjs';
import { hashBytes, sha } from './ota-guards.mjs';

function attributeValue(line) {
  // aapt2 prints string contents verbatim, not as JSON. Keep inner quotes and
  // backslashes intact, and exclude the optional Raw annotation from the value.
  const value = line.match(
    /^\s*A:\s+[^=]+=(?:"(.*?)"|(true|false|@0x[a-f0-9]+|0x[a-f0-9]+|-?\d+))(?: \(Raw: "(.*)"\))?\s*$/i,
  );
  // An unescaped annotation delimiter inside a string makes the dump ambiguous.
  // Never turn a prefix of such a value into valid OTA metadata.
  if (value?.[1] !== undefined && value?.[3]?.includes('" (Raw: "'))
    throw new Error('Android manifest string has an ambiguous Raw annotation.');
  return value?.[1] ?? value?.[2];
}
export function inspectManifestDump(
  manifest,
  resources,
  badging,
  { readFingerprint } = {},
) {
  const metadata = {};
  let current;
  for (const line of manifest.split(/\r?\n/)) {
    if (line.includes('E: meta-data')) current = {};
    if (current && /android:name\(/.test(line))
      current.name = attributeValue(line);
    if (current && /android:value\(/.test(line)) {
      current.value = attributeValue(line);
      if (current.name) metadata[current.name] = current.value;
      current = undefined;
    }
  }
  const field = (name) => metadata['expo.modules.updates.' + name];
  let runtimeVersion = field('EXPO_RUNTIME_VERSION');
  if (runtimeVersion?.startsWith('@0x')) {
    const id = runtimeVersion.slice(1);
    const lines = resources.split(/\r?\n/);
    const index = lines.findIndex((line) =>
      line.includes('resource ' + id + ' '),
    );
    runtimeVersion =
      index < 0
        ? undefined
        : lines
            .slice(index + 1, index + 5)
            .map((line) => line.match(/\(\) "([^"]+)"/)?.[1])
            .find(Boolean);
  }
  // Expo's Android UpdatesConfiguration resolves this sentinel from the APK's
  // assets/fingerprint, not from a replacement manifest string resource.
  if (runtimeVersion === 'file:fingerprint' && readFingerprint) {
    runtimeVersion = readFingerprint();
    if (
      typeof runtimeVersion !== 'string' ||
      runtimeVersion.length !== 40 ||
      !sha.test(runtimeVersion)
    )
      throw new Error(
        'APK assets/fingerprint is not a 40-character native fingerprint.',
      );
  }
  let headers = {};
  try {
    headers = JSON.parse(
      field('UPDATES_CONFIGURATION_REQUEST_HEADERS_KEY') ??
        field('EXPO_UPDATES_REQUEST_HEADERS') ??
        '{}',
    );
  } catch {
    throw new Error('Embedded update request headers could not be decoded.');
  }
  const packageName = badging.match(/package: name='([^']+)'/)?.[1];
  if (packageName !== productionPackage)
    throw new Error(
      'Inspect the production package com.gorkem.ekspersiz, not a development APK.',
    );
  const updateUrl = field('EXPO_UPDATE_URL');
  return {
    androidPackage: packageName,
    versionCode: Number(badging.match(/versionCode='(\d+)'/)?.[1]),
    versionName: badging.match(/versionName='([^']+)'/)?.[1],
    updatesEnabled: field('ENABLED') === 'true',
    updateUrl: updateUrl ?? null,
    runtimeVersion: runtimeVersion ?? null,
    channel: headers['expo-channel-name'] ?? null,
    startupCheck: field('EXPO_UPDATES_CHECK_ON_LAUNCH') ?? null,
    launchWaitMs: Number(field('EXPO_UPDATES_LAUNCH_WAIT_MS') ?? -1),
    otaCapable: field('ENABLED') === 'true' && !!updateUrl && !!runtimeVersion,
  };
}
export function verifyNativeOta(report, { channel, runtimeVersion }) {
  if (
    !report.otaCapable ||
    report.updateUrl !== `https://u.expo.dev/${easProject.id}` ||
    report.channel !== channel ||
    report.runtimeVersion !== runtimeVersion ||
    !sha.test(runtimeVersion) ||
    !['staging', 'production'].includes(channel) ||
    report.startupCheck !== 'ALWAYS' ||
    report.launchWaitMs !== 0
  )
    throw new Error(
      'APK does not embed the required project, channel, fingerprint runtime and nonblocking startup policy.',
    );
  return report;
}
export function readApkFingerprint(apk, { env = process.env } = {}) {
  const java = env.JAVA_HOME
    ? join(
        env.JAVA_HOME,
        'bin',
        process.platform === 'win32' ? 'java.exe' : 'java',
      )
    : 'java';
  const result = spawnSync(
    java,
    [
      fileURLToPath(new URL('./android/ApkFingerprint.java', import.meta.url)),
      apk,
    ],
    { env, encoding: 'utf8', timeout: 60000, maxBuffer: 1024 * 1024 },
  );
  if (
    result.status !== 0 ||
    result.stdout?.length !== 40 ||
    !sha.test(result.stdout)
  )
    throw new Error(
      `APK fingerprint asset inspection failed. ${result.error?.message ?? result.stderr?.trim() ?? 'Check Java 21 and assets/fingerprint.'}`,
    );
  return result.stdout;
}
export function inspectApk(apk, { aapt2, env = process.env } = {}) {
  const sdk =
    env.ANDROID_HOME ??
    env.ANDROID_SDK_ROOT ??
    (process.platform === 'win32' && env.LOCALAPPDATA
      ? join(env.LOCALAPPDATA, 'Android/Sdk')
      : undefined);
  const executable =
    aapt2 ??
    (sdk
      ? join(
          sdk,
          'build-tools/37.0.0',
          process.platform === 'win32' ? 'aapt2.exe' : 'aapt2',
        )
      : 'aapt2');
  if (!existsSync(apk))
    throw new Error('APK is not available for read-only inspection.');
  const dump = (args) => {
    const result = spawnSync(executable, args, {
      encoding: 'utf8',
      timeout: 60000,
      maxBuffer: 64 * 1024 * 1024,
    });
    if (result.status !== 0)
      throw new Error(
        'aapt2 inspection failed; install the documented Android build-tools.',
      );
    return result.stdout;
  };
  return {
    ...inspectManifestDump(
      dump(['dump', 'xmltree', apk, '--file', 'AndroidManifest.xml']),
      dump(['dump', 'resources', apk]),
      dump(['dump', 'badging', apk]),
      { readFingerprint: () => readApkFingerprint(apk, { env }) },
    ),
    sha256: hashBytes(readFileSync(apk)),
  };
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  if (!process.argv[2]?.endsWith('.apk'))
    throw new Error(
      'Usage: node scripts/ota-inspect-binary.mjs <production.apk> [staging|production <runtime>]',
    );
  const report = inspectApk(resolve(process.argv[2]));
  if (process.argv[3])
    verifyNativeOta(report, {
      channel: process.argv[3],
      runtimeVersion: process.argv[4],
    });
  console.log(JSON.stringify(report, null, 2));
}
