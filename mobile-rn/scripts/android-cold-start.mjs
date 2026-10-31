import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout } from 'node:timers/promises';

// Explicit target required; never uninstall, clear app data, or choose a device implicitly.
const [serial, apkPath, aabPath, appPackage, versionCode, outputPath] =
  process.argv.slice(2);
assert.ok(
  serial && apkPath && aabPath && outputPath && /^\d+$/.test(versionCode ?? ''),
  'Usage: node scripts/android-cold-start.mjs SERIAL APK AAB PACKAGE VERSION_CODE OUTPUT_DIR',
);
assert.match(appPackage, /^com\.gorkem\.ekspersiz(?:\.dev)?$/);
const root = fileURLToPath(new URL('..', import.meta.url));
const sdk = process.env.ANDROID_HOME ?? process.env.ANDROID_SDK_ROOT;
assert.ok(sdk, 'ANDROID_HOME or ANDROID_SDK_ROOT is required');
const adb = join(
  sdk,
  'platform-tools',
  process.platform === 'win32' ? 'adb.exe' : 'adb',
);
const java = process.env.JAVA_HOME
  ? join(
      process.env.JAVA_HOME,
      'bin',
      process.platform === 'win32' ? 'java.exe' : 'java',
    )
  : 'java';
const output = resolve(outputPath);
mkdirSync(output, { recursive: true });
function run(command, args, binary = false) {
  const result = spawnSync(command, args, {
    encoding: binary ? undefined : 'utf8',
    timeout: 60_000,
    maxBuffer: 24 * 1024 * 1024,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr?.toString());
  return result.stdout;
}
const device = (...args) => run(adb, ['-s', serial, ...args]).trim();
const constructors = (path) =>
  JSON.parse(
    run(java, [
      join(root, 'scripts/android/ReleaseIdentity.java'),
      'constructors',
      resolve(path),
    ]),
  );
const apk = constructors(apkPath),
  aab = constructors(aabPath);
assert.deepEqual(
  apk.dexSha256,
  aab.dexSha256,
  'APK DEX differs from the production AAB',
);
assert.equal(device('get-state'), 'device');
const report = {
  package: appPackage,
  versionCode: Number(versionCode),
  model: device('shell', 'getprop', 'ro.product.model'),
  api: device('shell', 'getprop', 'ro.build.version.sdk'),
  abi: device('shell', 'getprop', 'ro.product.cpu.abi'),
  physicalDevice:
    device('shell', 'getprop', 'ro.kernel.qemu') !== '1' &&
    device('shell', 'getprop', 'ro.boot.qemu') !== '1',
  apkSha256: createHash('sha256').update(readFileSync(apkPath)).digest('hex'),
  aabSha256: createHash('sha256').update(readFileSync(aabPath)).digest('hex'),
  dexSha256: apk.dexSha256,
  attempts: [],
  passed: false,
};
try {
  const install = device('install', '-r', resolve(apkPath));
  assert.match(
    install,
    /Success/,
    'APK installation failed; existing app data will not be deleted automatically',
  );
  const installed = device('shell', 'dumpsys', 'package', appPackage);
  assert.match(installed, new RegExp(`versionCode=${versionCode}\\b`));
  report.versionName = installed.match(/versionName=([^\s]+)/)?.[1];
  for (let attempt = 1; attempt <= 3; attempt++) {
    device('shell', 'am', 'force-stop', appPackage);
    assert.equal(
      device('shell', 'ps', '-A')
        .split('\n')
        .some((line) => line.trim().endsWith(` ${appPackage}`)),
      false,
    );
    // Device clock, so logcat filtering never depends on host timezone/clock skew.
    const since = device('shell', "date '+%m-%d %H:%M:%S.000'");
    const start = device(
      'shell',
      'am',
      'start',
      '-W',
      '-n',
      `${appPackage}/.MainActivity`,
    );
    assert.match(start, /Status: ok/);
    assert.doesNotMatch(start, /Error:|Exception|crash/i);
    let ui = '',
      activity = '',
      pid = '';
    const deadline = Date.now() + 60_000;
    while (Date.now() < deadline) {
      await setTimeout(2000);
      pid = device('shell', 'pidof', appPackage);
      assert.match(pid, /^\d+$/, 'Process died after cold start');
      activity = device('shell', 'dumpsys', 'activity', 'activities');
      device(
        'shell',
        'uiautomator',
        'dump',
        '/sdcard/ekspersiz-cold-start.xml',
      );
      ui = device('shell', 'cat', '/sdcard/ekspersiz-cold-start.xml');
      // RN screen content beyond the native splash, no login or paid flows.
      if (
        ui.includes(`package="${appPackage}"`) &&
        /Aracını tanı|Giriş Yap/.test(ui)
      )
        break;
    }
    assert.match(
      ui,
      /Aracını tanı|Giriş Yap/,
      'React Native onboarding/login did not render',
    );
    assert.ok(
      activity
        .split('\n')
        .some(
          (line) =>
            /(?:mResumedActivity|topResumedActivity)/.test(line) &&
            line.includes(`${appPackage}/.MainActivity`),
        ),
      'MainActivity is not resumed',
    );
    await setTimeout(10_000);
    assert.equal(
      device('shell', 'pidof', appPackage),
      pid,
      'Process restarted or died during observation',
    );
    const log = device('logcat', '-d', '-v', 'threadtime', '-T', since);
    const ownLog = device(
      'logcat',
      '-d',
      '-v',
      'threadtime',
      '-T',
      since,
      `--pid=${pid}`,
    );
    writeFileSync(join(output, `launch-${attempt}-logcat.txt`), ownLog);
    writeFileSync(join(output, `launch-${attempt}-ui.xml`), ui);
    writeFileSync(join(output, `launch-${attempt}-activity.txt`), activity);
    writeFileSync(
      join(output, `launch-${attempt}.png`),
      run(adb, ['-s', serial, 'exec-out', 'screencap', '-p'], true),
    );
    assert.doesNotMatch(
      ownLog,
      /FATAL EXCEPTION|Fatal signal|Failed to create an instance of class|NoSuchMethodException|ReactNativeJS:.*(?:TypeError|ReferenceError|Error:)/,
    );
    assert.ok(!log.includes(`ANR in ${appPackage}`), 'App ANR detected');
    report.attempts.push({
      attempt,
      pid,
      rnScreenRendered: true,
      observedAliveSeconds: 10,
      start,
    });
    console.log(
      `Cold start ${attempt}/3 passed (${report.physicalDevice ? 'physical' : 'emulator'}, API ${report.api}).`,
    );
  }
  report.passed = true;
} catch (error) {
  report.failure = error.message;
  throw error;
} finally {
  report.testedAt = new Date().toISOString();
  writeFileSync(
    join(output, 'cold-start.json'),
    JSON.stringify(report, null, 2) + '\n',
  );
}
