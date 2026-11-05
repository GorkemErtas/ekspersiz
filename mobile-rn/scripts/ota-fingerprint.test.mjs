import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';
import { firebase, publicEnv } from './ota-fixtures.mjs';

test(
  'actual Expo fingerprints match the SDK runtime resolver, share channels, ignore UI code and reject native changes',
  { timeout: 180000 },
  () => {
    const root = resolve('.');
    mkdirSync(join(root, '.ota'), { recursive: true });
    const directory = mkdtempSync(join(root, '.ota', 'fingerprint-test-'));
    const nativeDirectory = mkdtempSync(
      join(root, 'modules', 'ota-fingerprint-probe-'),
    );
    const probe = join(root, 'src', basename(nativeDirectory) + '.ts');
    const file = join(directory, 'firebase.json');
    writeFileSync(file, JSON.stringify(firebase()));
    const clean = { ...process.env };
    for (const name of Object.keys(clean))
      if (/^(?:EXPO_PUBLIC_|EXPO_UPDATES_|ANDROID_|GOOGLE_)/.test(name))
        delete clean[name];
    const code = `
      import {createRequire} from 'node:module';
      import {join,dirname,resolve} from 'node:path';
      import {mkdirSync,readFileSync} from 'node:fs';
      import {nativeFingerprint} from './scripts/ota-fingerprint.mjs';
      const root=process.cwd();
      const hash=await nativeFingerprint(root);
      if(process.env.COMPARE_SDK==='1') {
        const require=createRequire(resolve('package.json'));
        const utils=join(dirname(require.resolve('expo-updates/package.json')),'utils/build');
        const {resolveRuntimeVersionAsync}=require(join(utils,'resolveRuntimeVersionAsync.js'));
        const sdk=await resolveRuntimeVersionAsync(root,'android',{silent:true},{});
        if(sdk.runtimeVersion!==hash)throw new Error('SDK runtime policy differs from publishing guard');
        const {createFingerprintForBuildAsync}=require(join(utils,'createFingerprintForBuildAsync.js'));
        const destination=process.env.FINGERPRINT_ASSET_DIR;
        mkdirSync(destination,{recursive:true});
        process.env.EXPO_UPDATES_FINGERPRINT_OVERRIDE=hash;
        const log=console.log;
        console.log=()=>{};
        try { await createFingerprintForBuildAsync('android',root,destination); }
        finally { console.log=log; }
        if(readFileSync(join(destination,'fingerprint'),'utf8')!==sdk.runtimeVersion)
          throw new Error('SDK native fingerprint asset differs from EAS Update runtime');
      }
      console.log(hash);
    `;
    const run = (channel = 'staging', compare = false, native = false) => {
      const result = spawnSync(
        process.execPath,
        ['--input-type=module', '--eval', code],
        {
          cwd: root,
          env: {
            ...clean,
            ...publicEnv(file),
            EXPO_UPDATES_CHANNEL: channel,
            COMPARE_SDK: compare ? '1' : '0',
            FINGERPRINT_ASSET_DIR: join(directory, 'assets-' + channel),
            EXPO_UPDATES_FINGERPRINT_OVERRIDE: 'untrusted-shell-runtime',
            ...(native
              ? {
                  APP_CONFIG_MODE: 'native',
                  ANDROID_PLAY_MAX_VERSION_CODE: '54',
                  ANDROID_PLAY_SIGNING_SHA1: '12'.repeat(20),
                  ANDROID_PLAY_SIGNING_SHA256: '34'.repeat(32),
                  ANDROID_KEYSTORE_PROPERTIES_FILE: file,
                  ANDROID_KEYSTORE_BASE_DIR: directory,
                }
              : {}),
          },
          encoding: 'utf8',
          timeout: 60000,
        },
      );
      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout.trim(), /^[a-f0-9]{40}$/);
      return result.stdout.trim();
    };
    try {
      const initial = run('staging', true);
      assert.equal(run('production', true), initial);
      assert.equal(run('staging', true, true), initial);
      writeFileSync(probe, "export const probe = 'UI-only change';\n", {
        flag: 'wx',
      });
      assert.equal(run(), initial);
      writeFileSync(
        join(nativeDirectory, 'Probe.kt'),
        'class NewNativeBridge\n',
      );
      assert.notEqual(run(), initial);
    } finally {
      assert.ok(probe.startsWith(join(root, 'src')));
      rmSync(probe, { force: true });
      assert.ok(
        nativeDirectory.startsWith(
          join(root, 'modules', 'ota-fingerprint-probe-'),
        ),
      );
      assert.ok(directory.startsWith(join(root, '.ota', 'fingerprint-test-')));
      rmSync(nativeDirectory, { recursive: true, force: true });
      rmSync(directory, { recursive: true, force: true });
    }
  },
);
