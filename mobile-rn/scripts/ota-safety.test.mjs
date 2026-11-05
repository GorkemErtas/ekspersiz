import { Buffer } from 'node:buffer';
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { classifyChanges } from './ota-classify.mjs';
import { approvedRuntime, repository, updateMessage } from './ota-guards.mjs';
import { releaseUpdate } from './ota-release.mjs';
import { inspectOtaExport } from './ota-bundle.mjs';
import {
  promotionProvenance,
  verifyApprovalEnvironment,
  verifyStagingRun,
} from './ota-github.mjs';
import { easProject } from '../config/productionEnvironment.cjs';
import { recordBootstrapFailure } from './ota-audit.mjs';

const commitSha = 'a'.repeat(40),
  runtimeVersion = 'b'.repeat(40),
  environmentHash = 'c'.repeat(64),
  exportHash = 'd'.repeat(64);
const groupId = '11111111-1111-4111-8111-111111111111',
  newGroup = '22222222-2222-4222-8222-222222222222',
  updateId = '33333333-3333-4333-8333-333333333333';
const catalog = () => ({
  schemaVersion: 1,
  projectId: easProject.id,
  androidPackage: 'com.gorkem.ekspersiz',
  runtimes: [
    {
      runtimeVersion,
      environmentHash,
      sourceCommit: commitSha,
      verified: true,
      binaries: {
        staging: {
          sha256: 'e'.repeat(64),
          versionCode: 55,
          versionName: '1.0.3',
        },
        production: {
          sha256: 'f'.repeat(64),
          versionCode: 56,
          versionName: '1.0.3',
        },
      },
    },
  ],
});
const source = () => ({
  schemaVersion: 1,
  status: 'published',
  projectId: easProject.id,
  repository,
  channel: 'staging',
  commitSha,
  runtimeVersion,
  environmentHash,
  exportHash,
  groupId,
  runId: '100',
});
const context = (operation = 'staging') => ({
  CI: '1',
  EXPO_TOKEN: 'synthetic-token-only',
  GITHUB_ACTIONS: 'true',
  GITHUB_REPOSITORY: repository,
  GITHUB_REF: 'refs/heads/master',
  GITHUB_EVENT_NAME: operation === 'staging' ? 'push' : 'workflow_dispatch',
  GITHUB_SHA: commitSha,
  GITHUB_RUN_ID: '200',
  OTA_STAGING_RUN_ID: '100',
  OTA_APPROVAL_VERIFIED: 'true',
  OTA_STAGING_VERIFIED: 'true',
});
const branch = (name, id = name + '-id') => ({
  currentPage: {
    name,
    branchMapping: JSON.stringify({
      version: 0,
      data: [{ branchId: id, clientKey: 'true' }],
    }),
    updateBranches: [{ id, name }],
  },
});
const update = (channel, group = groupId) => ({
  id: updateId,
  group,
  branch: channel,
  runtimeVersion,
  platform: 'android',
  gitCommitHash: commitSha,
  message: updateMessage(commitSha, environmentHash),
  isRollBackToEmbedded: false,
});
function harness(operation = 'staging', changes = {}) {
  const calls = [];
  let exported = 0;
  const input = {
    operation,
    env: context(operation),
    commitSha,
    runtimeVersion,
    environmentHash,
    catalog: catalog(),
    stagingRecord: source(),
    groupId,
    rollout: operation === 'rollback' ? '100' : '10',
    ...changes,
  };
  const io = {
    exportBundle: async () => {
      exported++;
      return exportHash;
    },
    eas: async (args) => {
      calls.push(args);
      if (args[0] === 'channel:view') return branch(args[1]);
      if (args[0] === 'update:view') return [update('staging')];
      if (args[0] === 'update') return [update('staging')];
      if (args[0] === 'update:republish')
        return [
          {
            ...update('production', newGroup),
            branch: { name: 'production' },
            runtimeVersion: undefined,
            runtime: { version: runtimeVersion },
          },
        ];
      throw new Error('Unexpected EAS command');
    },
  };
  return {
    input,
    io,
    calls,
    exported: () => exported,
    mutations: () =>
      calls.filter((args) => ['update', 'update:republish'].includes(args[0])),
  };
}

test('classification is conservative for dependencies, config, bridges, native branding, unknown files and renames', () => {
  assert.equal(
    classifyChanges([
      'mobile-rn/src/features/home/HomeScreen.tsx',
      'mobile-rn/assets/guide/new.png',
    ]).kind,
    'ota',
  );
  assert.equal(
    classifyChanges([
      'docs/production/OTA_UPDATES.md',
      'mobile-rn/scripts/ota-safety.test.mjs',
    ]).kind,
    'none',
  );
  for (const file of [
    'mobile-rn/package-lock.json',
    'mobile-rn/package.json',
    'mobile-rn/app.config.ts',
    'mobile-rn/modules/bridge.kt',
    'mobile-rn/plugins/new.cjs',
    'mobile-rn/src/platform/native.ts',
    'mobile-rn/assets/images/ekspersiz_logo.png',
    'mobile-rn/unknown.json',
    '.github/workflows/mobile-ota-promote.yml',
    'mobile-rn/secrets/google-services.json',
  ])
    assert.equal(
      classifyChanges([file, 'mobile-rn/app/new.tsx']).kind,
      'native',
      file,
    );
  assert.equal(
    classifyChanges([
      'mobile-rn/modules/removed.kt',
      'mobile-rn/src/renamed.ts',
    ]).kind,
    'native',
  );
  assert.throws(() => classifyChanges(['../mobile-rn/app/foo.tsx']));
});

test('unregistered or incompatible native runtimes, environments and incomplete binary evidence fail closed', () => {
  assert.ok(approvedRuntime(catalog(), runtimeVersion, environmentHash));
  for (const change of [
    { ...catalog(), runtimes: [] },
    { ...catalog(), projectId: groupId },
    { ...catalog(), runtimes: [{ ...catalog().runtimes[0], verified: false }] },
    {
      ...catalog(),
      runtimes: [
        {
          ...catalog().runtimes[0],
          binaries: { staging: catalog().runtimes[0].binaries.staging },
        },
      ],
    },
  ])
    assert.throws(() =>
      approvedRuntime(change, runtimeVersion, environmentHash),
    );
  assert.throws(() =>
    approvedRuntime(catalog(), 'x'.repeat(40), environmentHash),
  );
  assert.throws(() =>
    approvedRuntime(catalog(), runtimeVersion, '9'.repeat(64)),
  );
});

test('staging exports once and publishes only the validated Android artifact with auditable metadata', async () => {
  const h = harness();
  const result = await releaseUpdate(h.input, h.io);
  assert.equal(h.exported(), 1);
  assert.equal(h.mutations().length, 1);
  assert.ok(h.mutations()[0].includes('--skip-bundler'));
  assert.equal(
    h.mutations()[0][h.mutations()[0].indexOf('--channel') + 1],
    'staging',
  );
  assert.equal(result.groupId, groupId);
  assert.equal(result.commitSha, commitSha);
  assert.equal(result.exportHash, exportHash);
  assert.equal(result.status, 'published');
});

test('first staging can be verified before production migration, but promotion still needs a production binary', async () => {
  const proof = catalog();
  delete proof.runtimes[0].binaries.production;
  const stage = harness('staging', { catalog: proof });
  assert.equal(
    (await releaseUpdate(stage.input, stage.io)).status,
    'published',
  );
  const prod = harness('promote', { catalog: proof });
  await assert.rejects(releaseUpdate(prod.input, prod.io), /production binary/);
  assert.equal(prod.mutations().length, 0);
});

test('missing EAS bootstrap credentials leave an audit receipt without overwriting a later result', () => {
  const prefix = join(tmpdir(), 'ekspersiz-ota-audit-'),
    directory = mkdtempSync(prefix);
  try {
    assert.equal(
      recordBootstrapFailure(directory, 'staging', context(), commitSha),
      true,
    );
    assert.equal(
      recordBootstrapFailure(directory, 'staging', context(), commitSha),
      false,
    );
  } finally {
    assert.ok(directory.startsWith(prefix));
    rmSync(directory, { recursive: true, force: true });
  }
});

test('promotion reuses the exact tested group, supports the actual EAS GraphQL response, and never rebuilds', async () => {
  const h = harness('promote');
  const result = await releaseUpdate(h.input, h.io);
  assert.equal(h.exported(), 0);
  assert.equal(h.mutations().length, 1);
  assert.equal(h.mutations()[0][0], 'update:republish');
  assert.equal(
    h.mutations()[0][h.mutations()[0].indexOf('--group') + 1],
    groupId,
  );
  assert.equal(result.channel, 'production');
  assert.equal(result.sourceGroupId, groupId);
  assert.equal(result.groupId, newGroup);
  assert.equal(result.exportHash, exportHash);
});

test('missing credentials, untrusted CI, missing approval, source/environment/runtime drift and wrong group block mutations', async () => {
  const cases = [
    ['staging', { env: { ...context(), EXPO_TOKEN: '' } }],
    ['staging', { env: { ...context(), GITHUB_REF: 'refs/heads/feature' } }],
    ['staging', { env: { ...context(), GITHUB_EVENT_NAME: 'pull_request' } }],
    ['staging', { env: { ...context(), GITHUB_SHA: '0'.repeat(40) } }],
    [
      'promote',
      { env: { ...context('promote'), OTA_APPROVAL_VERIFIED: 'false' } },
    ],
    [
      'promote',
      { env: { ...context('promote'), OTA_STAGING_VERIFIED: 'false' } },
    ],
    [
      'promote',
      { stagingRecord: { ...source(), environmentHash: '0'.repeat(64) } },
    ],
    [
      'promote',
      { stagingRecord: { ...source(), runtimeVersion: '0'.repeat(40) } },
    ],
    ['promote', { stagingRecord: { ...source(), commitSha: '0'.repeat(40) } }],
    ['promote', { stagingRecord: { ...source(), runId: 'not-the-run' } }],
    ['promote', { groupId: newGroup }],
    ['promote', { rollout: '1;echo unsafe' }],
  ];
  for (const [operation, changes] of cases) {
    const h = harness(operation, changes);
    await assert.rejects(releaseUpdate(h.input, h.io));
    assert.equal(h.mutations().length, 0);
  }
});

test('cross-channel routing, source-group substitution and export failures never publish', async () => {
  for (const scenario of ['same-branch', 'wrong-group', 'export-failed']) {
    const h = harness(scenario === 'wrong-group' ? 'promote' : 'staging');
    const original = h.io.eas;
    h.io.eas = async (args) => {
      if (scenario === 'same-branch' && args[0] === 'channel:view')
        return branch(args[1], 'same-branch-id');
      if (scenario === 'wrong-group' && args[0] === 'update:view')
        return [{ ...update('staging'), group: newGroup }];
      return original(args);
    };
    if (scenario === 'export-failed')
      h.io.exportBundle = async () => {
        throw new Error('Interrupted export');
      };
    await assert.rejects(releaseUpdate(h.input, h.io));
    assert.equal(h.mutations().length, 0);
  }
});

test('rollback is explicit, uses the prior artifact at 100 percent, and only then supersedes an active rollout', async () => {
  const h = harness('rollback');
  const result = await releaseUpdate(h.input, h.io);
  assert.equal(h.exported(), 0);
  assert.equal(result.rolloutPercentage, 100);
  assert.ok(h.mutations()[0].includes('--force-end-active-rollout'));
  const bad = harness('rollback', { rollout: '10' });
  await assert.rejects(releaseUpdate(bad.input, bad.io));
  assert.equal(bad.mutations().length, 0);
});

test('ambiguous publishing failures are not retried and never trigger an automatic rollback', async () => {
  const h = harness();
  const original = h.io.eas;
  h.io.eas = async (args) => {
    if (args[0] === 'update') {
      h.calls.push(args);
      throw new Error('Network interrupted');
    }
    return original(args);
  };
  await assert.rejects(releaseUpdate(h.input, h.io), /Network interrupted/);
  assert.equal(h.mutations().length, 1);
  assert.equal(h.mutations()[0][0], 'update');
});

test('bundle validation rejects private files, leaked credentials, test/fixture code, missing maps and wrong engines', () => {
  const prefix = join(tmpdir(), 'ekspersiz-ota-bundle-');
  const directory = mkdtempSync(prefix);
  const metadata = {
    version: 0,
    bundler: 'metro',
    fileMetadata: { android: { bundle: 'bundle.hbc', assets: [] } },
  };
  const writeMap = (sources, content = '') =>
    writeFileSync(
      join(directory, 'bundle.hbc.map'),
      JSON.stringify({ version: 3, sources, sourcesContent: [content] }),
    );
  try {
    writeFileSync(join(directory, 'metadata.json'), JSON.stringify(metadata));
    writeFileSync(
      join(directory, 'bundle.hbc'),
      Buffer.from('c61fbc03c103191f', 'hex'),
    );
    writeMap(['src/features/home/HomeScreen.tsx']);
    assert.match(inspectOtaExport(directory, {}), /^[a-f0-9]{64}$/);
    writeMap([
      '/node_modules/react-native-reanimated/scripts/validate-worklets-version.js',
    ]);
    assert.match(inspectOtaExport(directory, {}), /^[a-f0-9]{64}$/);
    writeFileSync(join(directory, 'upload.jks'), 'forbidden');
    assert.throws(() => inspectOtaExport(directory, {}), /Signing/);
    rmSync(join(directory, 'upload.jks'));
    writeMap(['visual/fixture-server.mjs']);
    assert.throws(() => inspectOtaExport(directory, {}), /Fixture/);
    writeMap(['src/features/home/HomeScreen.tsx'], 'synthetic-private-token');
    assert.throws(
      () =>
        inspectOtaExport(directory, { EXPO_TOKEN: 'synthetic-private-token' }),
      /credential/,
    );
    writeMap(['src/features/home/HomeScreen.tsx']);
    rmSync(join(directory, 'bundle.hbc.map'));
    assert.throws(() => inspectOtaExport(directory, {}), /source maps/);
    writeFileSync(join(directory, 'bundle.hbc'), 'plain JS');
    assert.throws(() => inspectOtaExport(directory, {}), /Hermes/);
  } finally {
    assert.ok(directory.startsWith(prefix));
    rmSync(directory, { recursive: true, force: true });
  }
});

test('promotion provenance requires successful master checks, the exact workflow and real approval protection', async () => {
  const run = {
    id: 100,
    repository: { full_name: repository },
    event: 'push',
    head_branch: 'master',
    head_sha: commitSha,
    status: 'completed',
    conclusion: 'success',
    workflow_id: 5,
  };
  const workflow = { id: 5, path: '.github/workflows/mobile-rn-checks.yml' };
  assert.equal(verifyStagingRun(run, workflow, '100'), commitSha);
  for (const changed of [
    { ...run, event: 'pull_request' },
    { ...run, conclusion: 'failure' },
    { ...run, head_branch: 'feature' },
  ])
    assert.throws(() => verifyStagingRun(changed, workflow, '100'));
  const env = {
    ...context('promote'),
    GITHUB_TOKEN: 'read-only-token',
    OTA_UPDATE_GROUP_ID: groupId,
    OTA_OPERATION: 'promote',
    OTA_ROLLOUT_PERCENTAGE: '10',
  };
  const fetcher = async (url) => ({
    ok: true,
    json: async () =>
      url.includes('/environments/')
        ? {
            name: 'ota-production',
            protection_rules: [{ type: 'required_reviewers', reviewers: [{}] }],
          }
        : url.includes('/artifacts')
          ? {
              artifacts: [{ name: `ota-staging-${commitSha}`, expired: false }],
            }
          : url.includes('/workflows/')
            ? workflow
            : run,
  });
  assert.equal((await promotionProvenance(env, fetcher)).commitSha, commitSha);
  await assert.rejects(
    verifyApprovalEnvironment(env, async () => ({
      ok: true,
      json: async () => ({ name: 'ota-production', protection_rules: [] }),
    })),
    /required reviewers/,
  );
  await assert.rejects(
    promotionProvenance({ ...env, OTA_STAGING_VERIFIED: 'false' }, fetcher),
  );
});
