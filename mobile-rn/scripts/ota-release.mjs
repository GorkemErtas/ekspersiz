import { Buffer } from 'node:buffer';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import {
  productionEnvironmentConfig,
  easProject,
} from '../config/productionEnvironment.cjs';
import { otaUpdateConfig } from '../config/otaUpdate.cjs';
import { nativeFingerprint } from './ota-fingerprint.mjs';
import { inspectOtaExport } from './ota-bundle.mjs';
import {
  approvedRuntime,
  channelBranch,
  normalizePublishedUpdates,
  repository,
  rolloutPercentage,
  sha,
  sha256,
  updateMessage,
  verifyRemoteGroup,
  verifyStagingRecord,
} from './ota-guards.mjs';

export function publishingContext(env, operation, commitSha) {
  if (!env.EXPO_TOKEN?.trim())
    throw new Error('EXPO_TOKEN is required for publishing.');
  if (
    !env.CI ||
    env.GITHUB_ACTIONS !== 'true' ||
    env.GITHUB_REPOSITORY !== repository ||
    env.GITHUB_REF !== 'refs/heads/master' ||
    !sha.test(commitSha)
  )
    throw new Error('Publishing requires the trusted master GitHub workflow.');
  if (
    operation === 'staging' &&
    (env.GITHUB_EVENT_NAME !== 'push' || env.GITHUB_SHA !== commitSha)
  )
    throw new Error(
      'Automatic staging requires the validated master push SHA.',
    );
  if (
    operation !== 'staging' &&
    (env.GITHUB_EVENT_NAME !== 'workflow_dispatch' ||
      env.OTA_APPROVAL_VERIFIED !== 'true' ||
      env.OTA_STAGING_VERIFIED !== 'true')
  )
    throw new Error(
      'Production needs an approved environment and explicit staging verification.',
    );
}

export async function releaseUpdate(input, io) {
  const {
    operation,
    commitSha,
    runtimeVersion,
    environmentHash,
    catalog,
    env,
  } = input;
  if (!['staging', 'promote', 'rollback'].includes(operation))
    throw new Error('Unknown publishing operation.');
  publishingContext(env, operation, commitSha);
  approvedRuntime(
    catalog,
    runtimeVersion,
    environmentHash,
    operation !== 'staging',
  );
  const stagingBranch = channelBranch(
    await io.eas(['channel:view', 'staging', '--json', '--non-interactive']),
    'staging',
  );
  const productionBranch = channelBranch(
    await io.eas(['channel:view', 'production', '--json', '--non-interactive']),
    'production',
  );
  if (stagingBranch === productionBranch)
    throw new Error('Staging and production cannot share an update branch.');
  const record = {
    schemaVersion: 1,
    projectId: easProject.id,
    repository,
    commitSha,
    runtimeVersion,
    environmentHash,
    operation,
    runId: env.GITHUB_RUN_ID,
    channel: operation === 'staging' ? 'staging' : 'production',
  };
  let updates;
  if (operation === 'staging') {
    record.exportHash = await io.exportBundle();
    if (!sha256.test(record.exportHash))
      throw new Error('Export validation did not produce a SHA-256 digest.');
    await io.beforePublish?.(record);
    // env:exec already loaded one production snapshot. Avoid a second environment
    // fetch changing config/runtime after this artifact was validated. Pinned EAS
    // CLI supports preloaded environments in CI without --environment.
    updates = await io.eas([
      'update',
      '--channel',
      'staging',
      '--platform',
      'android',
      '--skip-bundler',
      '--input-dir',
      '.ota/export',
      '--message',
      updateMessage(commitSha, environmentHash),
      '--json',
      '--non-interactive',
    ]);
  } else {
    const source = verifyStagingRecord(input.stagingRecord, input.groupId);
    if (
      source.commitSha !== commitSha ||
      source.runtimeVersion !== runtimeVersion ||
      source.environmentHash !== environmentHash ||
      source.runId !== env.OTA_STAGING_RUN_ID
    )
      throw new Error(
        'Promotion environment, commit or runtime differs from verified staging.',
      );
    verifyRemoteGroup(
      await io.eas(['update:view', source.groupId, '--json']),
      source,
    );
    const percent = rolloutPercentage(input.rollout, operation);
    record.sourceGroupId = source.groupId;
    record.exportHash = source.exportHash;
    record.rolloutPercentage = percent;
    await io.beforePublish?.(record);
    updates = await io.eas([
      'update:republish',
      '--group',
      source.groupId,
      '--destination-channel',
      'production',
      '--platform',
      'android',
      '--rollout-percentage',
      String(percent),
      ...(operation === 'rollback' ? ['--force-end-active-rollout'] : []),
      '--message',
      updateMessage(commitSha, environmentHash),
      '--json',
      '--non-interactive',
    ]);
  }
  updates = normalizePublishedUpdates(updates);
  const groupId = updates?.[0]?.group;
  await io.afterResponse?.({ groupId });
  verifyRemoteGroup(updates, { ...record, groupId }, record.channel);
  return {
    ...record,
    status: 'published',
    groupId,
    updateIds: updates.map((item) => item.id),
    publishedAt: new Date().toISOString(),
  };
}

function executeEas(args, env, root) {
  const windows = process.platform === 'win32';
  if (windows && args.some((arg) => !/^[-A-Za-z0-9_:.,=/]+$/.test(arg)))
    throw new Error('Unsafe Windows EAS argument.');
  const result = spawnSync(
    windows ? (env.ComSpec ?? 'cmd.exe') : 'eas',
    windows ? ['/d', '/c', 'eas.cmd', ...args] : args,
    {
      cwd: root,
      env,
      encoding: 'utf8',
      timeout: 900000,
      maxBuffer: 8 * 1024 * 1024,
    },
  );
  if (result.status !== 0)
    throw new Error(
      `EAS ${args[0]} failed (exit ${result.status ?? 'unavailable'}). No automatic retry or rollback was attempted.`,
    );
  try {
    return JSON.parse(result.stdout);
  } catch {
    throw new Error(
      `EAS ${args[0]} returned an unrecognized response; inspect Expo before retrying.`,
    );
  }
}

export function prepareOtaEnvironment(original, root, channel) {
  if (
    original.APP_VARIANT !== 'production' ||
    original.APP_CONFIG_MODE !== 'ota' ||
    original.EXPO_NO_DOTENV !== '1'
  )
    throw new Error(
      'Load the explicit production EAS environment in OTA config mode, with dotenv disabled.',
    );
  const env = { ...original, EXPO_UPDATES_CHANNEL: channel };
  if (env.GOOGLE_SERVICES_FILE !== './secrets/google-services.production.json')
    throw new Error(
      'Use the same canonical Firebase client path in native builds and OTA.',
    );
  const directory = join(root, 'secrets'),
    file = join(directory, 'google-services.production.json');
  if (existsSync(directory) && lstatSync(directory).isSymbolicLink())
    throw new Error('Firebase directory cannot be a symlink.');
  if (env.GOOGLE_SERVICES_JSON_BASE64) {
    const bytes = Buffer.from(env.GOOGLE_SERVICES_JSON_BASE64, 'base64');
    if (
      bytes.toString('base64') !== env.GOOGLE_SERVICES_JSON_BASE64 ||
      !bytes.length
    )
      throw new Error('Invalid Firebase client metadata encoding.');
    let client;
    try {
      client = JSON.parse(bytes.toString('utf8'));
    } catch {
      throw new Error('Invalid Firebase Android client JSON.');
    }
    if (client.private_key || client.type === 'service_account')
      throw new Error(
        'Service-account credentials are forbidden in OTA metadata.',
      );
    mkdirSync(directory, { recursive: true });
    if (existsSync(file)) {
      if (lstatSync(file).isSymbolicLink() || !bytes.equals(readFileSync(file)))
        throw new Error(
          'Existing Firebase client metadata differs; it will not be overwritten.',
        );
    } else writeFileSync(file, bytes, { mode: 0o600, flag: 'wx' });
  }
  const shared = productionEnvironmentConfig(env, root);
  const ota = otaUpdateConfig(env, { production: true });
  if (!ota) throw new Error('OTA publishing requires explicit enablement.');
  return { env, shared };
}

async function main() {
  const root = fileURLToPath(new URL('..', import.meta.url));
  const operation = process.argv[2];
  if (!['check', 'staging', 'promote', 'rollback'].includes(operation))
    throw new Error('Use check, staging, promote or rollback.');
  const reports = join(root, '.ota/reports');
  mkdirSync(reports, { recursive: true });
  const audit = join(reports, 'publication.json');
  let record = {
    schemaVersion: 1,
    status: 'failed',
    operation,
    projectId: easProject.id,
    repository,
    commitSha: execFileSync('git', ['rev-parse', 'HEAD'], {
      cwd: root,
      encoding: 'utf8',
    }).trim(),
    runId: process.env.GITHUB_RUN_ID,
    channel: ['staging', 'check'].includes(operation)
      ? 'staging'
      : 'production',
    runtimeVersion: null,
    environmentHash: null,
  };
  try {
    const { env, shared } = prepareOtaEnvironment(
      process.env,
      root,
      operation === 'staging' || operation === 'check'
        ? 'staging'
        : 'production',
    );
    Object.assign(process.env, env);
    const catalog = JSON.parse(
      readFileSync(join(root, 'ota/native-runtimes.json'), 'utf8'),
    );
    const runtimeVersion = await nativeFingerprint(root);
    Object.assign(record, {
      runtimeVersion,
      environmentHash: shared.environmentHash,
    });
    const baseline = approvedRuntime(
      catalog,
      runtimeVersion,
      shared.environmentHash,
      !['staging', 'check'].includes(operation),
    );
    const commitSha = execFileSync('git', ['rev-parse', 'HEAD'], {
      cwd: root,
      encoding: 'utf8',
    }).trim();
    execFileSync(
      'git',
      ['merge-base', '--is-ancestor', baseline.sourceCommit, commitSha],
      { cwd: root },
    );
    Object.assign(record, {
      repository,
      commitSha,
      runtimeVersion,
      environmentHash: shared.environmentHash,
      channel:
        operation === 'staging' || operation === 'check'
          ? 'staging'
          : 'production',
      runId: env.GITHUB_RUN_ID,
    });
    if (operation === 'check') {
      record = {
        ...record,
        status: 'validated',
        runtimeVersion,
        environmentHash: shared.environmentHash,
        commitSha,
      };
      console.log(
        'Production environment and verified native runtime match. Nothing was published.',
      );
      return;
    }
    if (
      execFileSync('git', ['status', '--porcelain'], {
        cwd: root,
        encoding: 'utf8',
      }).trim()
    )
      throw new Error(
        'Publishing requires a clean checkout, including untracked source files.',
      );
    if (operation !== 'staging') {
      const { verifyApprovalEnvironment } = await import('./ota-github.mjs');
      await verifyApprovalEnvironment(env);
    }
    const stagingRecord =
      operation === 'staging'
        ? undefined
        : JSON.parse(
            readFileSync(join(root, '.ota/promotion/publication.json'), 'utf8'),
          );
    record = await releaseUpdate(
      {
        operation,
        env,
        catalog,
        commitSha,
        runtimeVersion,
        environmentHash: shared.environmentHash,
        stagingRecord,
        groupId: env.OTA_UPDATE_GROUP_ID,
        rollout: env.OTA_ROLLOUT_PERCENTAGE,
      },
      {
        eas: async (args) => executeEas(args, env, root),
        beforePublish: async (details) => {
          record = {
            ...details,
            status: 'publishing',
            attemptedAt: new Date().toISOString(),
          };
          writeFileSync(audit, JSON.stringify(record, null, 2) + '\n');
        },
        afterResponse: async ({ groupId }) => {
          record.groupId = groupId;
        },
        exportBundle: async () => {
          const result = spawnSync(
            process.execPath,
            [
              'node_modules/expo/bin/cli',
              'export',
              '--platform',
              'android',
              '--source-maps',
              '--output-dir',
              '.ota/export',
            ],
            { cwd: root, env, stdio: 'inherit', timeout: 600000 },
          );
          if (result.status !== 0)
            throw new Error('Production Android export failed.');
          const exportHash = inspectOtaExport(join(root, '.ota/export'), env);
          if ((await nativeFingerprint(root)) !== runtimeVersion)
            throw new Error('Native fingerprint changed during export.');
          return exportHash;
        },
      },
    );
    console.log(
      `Published ${record.channel} group ${record.groupId}, runtime ${record.runtimeVersion}, source ${record.commitSha}.`,
    );
  } catch (error) {
    if (record.status === 'publishing') record.status = 'unconfirmed';
    throw error;
  } finally {
    writeFileSync(audit, JSON.stringify(record, null, 2) + '\n');
    if (process.env.GITHUB_STEP_SUMMARY) {
      const { appendFileSync } = await import('node:fs');
      appendFileSync(
        process.env.GITHUB_STEP_SUMMARY,
        `\n### OTA ${operation}: ${record.status}\n\nGroup: ${record.groupId ?? 'none recorded; inspect Expo before retrying after an ambiguous network failure'}\n\nRuntime: ${record.runtimeVersion ?? 'not validated'}\n\nCommit: ${record.commitSha ?? 'not validated'}\n`,
      );
    }
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
  await main();
