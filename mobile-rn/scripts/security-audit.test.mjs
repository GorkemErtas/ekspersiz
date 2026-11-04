import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { evaluateAudit } from './security-audit.mjs';
import { checkSources } from './check-runtime-bundle.mjs';
import {
  checkManifest,
  checkSplashResources,
} from './check-android-manifest.mjs';
import splashPlugin from '../plugins/withAndroidSplashApi33.cjs';
const date = new Date('2026-10-30T00:00:00Z');
const advisory = {
  name: 'zod',
  severity: 'high',
  url: 'https://github.com/advisories/GHSA-mrhx-c7xc-m3w5',
};
const report = () => ({
  auditReportVersion: 2,
  metadata: { vulnerabilities: { high: 3 } },
  vulnerabilities: {
    zod: { severity: 'high', via: [advisory] },
    '@expo/cli': { severity: 'high', via: ['zod'] },
    expo: { severity: 'high', via: ['@expo/cli'] },
  },
});
test('only the reviewed tooling chain is temporarily accepted', () => {
  assert.equal(evaluateAudit(report(), date).accepted.length, 3);
  assert.deepEqual(evaluateAudit(report(), date).blocked, []);
});
test('new advisories, runtime packages and critical findings fail the gate', () => {
  for (const [name, finding] of [
    [
      'zod',
      {
        severity: 'high',
        via: [{ ...advisory, url: 'https://example.invalid/new-advisory' }],
      },
    ],
    ['new-runtime-package', { severity: 'high', via: ['zod'] }],
    ['expo', { severity: 'critical', via: ['@expo/cli'] }],
  ]) {
    const value = report();
    value.vulnerabilities[name] = finding;
    assert.ok(evaluateAudit(value, date).blocked.includes(name));
  }
});
test('expired exceptions and failed registry responses cannot pass', () => {
  assert.equal(
    evaluateAudit(report(), new Date('2026-11-30')).blocked.length,
    3,
  );
  for (const value of [
    {},
    { error: { code: 'ENOTFOUND' } },
    { ...report(), metadata: {} },
  ])
    assert.throws(() => evaluateAudit(value, date));
});
test('the advisory exception cannot cover an imported runtime copy', () => {
  checkSources([
    'src/core/api.ts',
    'node_modules/expo/build/Expo.js',
    '/node_modules/@expo/cli/build/metro-require/require.js',
  ]);
  for (const path of [
    'node_modules/zod/lib/index.js',
    'C:\\app\\node_modules\\deepmerge\\index.js',
    '../node_modules/@expo/cli/build/index.js',
  ])
    assert.throws(() => checkSources([path]));
});

test('merged native permissions detect global microphone removal and accidental broad media access', () => {
  const names = [
    'CAMERA',
    'RECORD_AUDIO',
    'POST_NOTIFICATIONS',
    'INTERNET',
    'ACCESS_FINE_LOCATION',
    'ACCESS_COARSE_LOCATION',
  ];
  const xml =
    names
      .map(
        (name) =>
          `<uses-permission android:name="android.permission.${name}"/>`,
      )
      .join('') +
    '<uses-permission android:name="com.android.vending.BILLING"/>';
  checkManifest(xml);
  assert.throws(() =>
    checkManifest(
      xml.replace(
        'android.permission.RECORD_AUDIO',
        'android.permission.UNKNOWN',
      ),
    ),
  );
  assert.throws(() =>
    checkManifest(
      xml +
        '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>',
    ),
  );
});

test('splash API 33 resource keeps the complete design while lower API styles exclude the new attribute', () => {
  const items = [
    'windowSplashScreenBackground',
    'windowSplashScreenAnimatedIcon',
    'postSplashScreenTheme',
    'android:windowSplashScreenBehavior',
  ].map((name) => ({ $: { name }, _: name }));
  const styles = {
    resources: {
      style: [
        {
          $: { name: 'Theme.App.SplashScreen', parent: 'Theme.SplashScreen' },
          item: structuredClone(items),
        },
      ],
    },
  };
  const api33 = splashPlugin.splitSplashStyle(styles);
  assert.deepEqual(api33.item, items);
  assert.deepEqual(styles.resources.style[0].item, items.slice(0, -1));
  assert.equal(splashPlugin.splitSplashStyle(styles), undefined);
  const xml = (list) =>
    list.map((item) => `<item name="${item.$.name}">${item._}</item>`).join('');
  checkSplashResources(xml(items.slice(0, -1)), xml(items));
  assert.throws(() =>
    checkSplashResources(xml(items.slice(0, -1)), '<resources/>'),
  );
});

test('audit CLI checks the lockfile and fails on an invalid registry report', () => {
  const directory = mkdtempSync(join(tmpdir(), 'ekspersiz-audit-'));
  try {
    const mockNpm = join(directory, 'npm.cjs');
    const argsFile = join(directory, 'audit-args.json');
    const clean = {
      auditReportVersion: 2,
      metadata: { vulnerabilities: { high: 0, critical: 0 } },
      vulnerabilities: {},
    };
    const mock = (value) =>
      writeFileSync(
        mockNpm,
        `
      if (process.argv[2] === 'ping') process.exit(0);
      require('node:fs').writeFileSync(process.env.TEST_NPM_ARGS, JSON.stringify(process.argv.slice(2)));
      console.log(${JSON.stringify(JSON.stringify(value))});
    `,
      );
    const run = () =>
      spawnSync(
        process.execPath,
        [fileURLToPath(new URL('./security-audit.mjs', import.meta.url))],
        {
          cwd: directory,
          env: {
            ...process.env,
            npm_execpath: mockNpm,
            TEST_NPM_ARGS: argsFile,
          },
          encoding: 'utf8',
          timeout: 10000,
        },
      );
    mock(clean);
    assert.equal(run().status, 0);
    assert.deepEqual(JSON.parse(readFileSync(argsFile, 'utf8')), [
      'audit',
      '--package-lock-only',
      '--json',
    ]);
    mock({ error: { code: 'ENOTFOUND' } });
    assert.equal(run().status, 1);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
