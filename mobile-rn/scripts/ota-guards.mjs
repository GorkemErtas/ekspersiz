import { createHash } from 'node:crypto';
import {
  easProject,
  productionPackage,
} from '../config/productionEnvironment.cjs';

export const repository = 'GorkemErtas/ekspersiz';
export const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const sha = /^[0-9a-f]{40}$/;
export const sha256 = /^[0-9a-f]{64}$/;
export const updateMessage = (commit, environmentHash) =>
  `ota-${commit}-env-${environmentHash}`;
export function approvedRuntime(
  catalog,
  runtimeVersion,
  environmentHash,
  requireProduction = true,
) {
  if (
    catalog.schemaVersion !== 1 ||
    catalog.projectId !== easProject.id ||
    catalog.androidPackage !== productionPackage ||
    !Array.isArray(catalog.runtimes)
  )
    throw new Error('Invalid approved native runtime catalog.');
  const matches = catalog.runtimes.filter(
    (item) => item.runtimeVersion === runtimeVersion,
  );
  const record = matches[0];
  if (
    matches.length !== 1 ||
    !sha.test(runtimeVersion) ||
    record?.verified !== true ||
    record.environmentHash !== environmentHash ||
    !sha256.test(environmentHash) ||
    !sha.test(record.sourceCommit)
  )
    throw new Error(
      'No verified native binary baseline for this runtime and public environment. An authorized OTA-enabled native migration is required.',
    );
  for (const channel of requireProduction
    ? ['staging', 'production']
    : ['staging']) {
    const binary = record.binaries?.[channel];
    if (
      !sha256.test(binary?.sha256) ||
      !Number.isSafeInteger(binary?.versionCode) ||
      binary.versionCode < 1 ||
      binary.versionCode > 2_100_000_000 ||
      !/^\d+\.\d+\.\d+$/.test(binary?.versionName)
    )
      throw new Error(`Missing verified ${channel} binary evidence.`);
  }
  if (
    requireProduction &&
    (record.binaries.staging.versionCode ===
      record.binaries.production.versionCode ||
      record.binaries.staging.versionName !==
        record.binaries.production.versionName)
  )
    throw new Error(
      'Channel binaries need distinct Play versionCodes and matching versionNames.',
    );
  return record;
}
export function channelBranch(response, name) {
  const channel = response.currentPage;
  let mapping;
  try {
    mapping = JSON.parse(channel.branchMapping);
  } catch {
    throw new Error('Channel routing could not be verified.');
  }
  const branches = channel.updateBranches;
  if (
    channel.name !== name ||
    channel.isPaused ||
    !Array.isArray(branches) ||
    branches.length !== 1 ||
    branches[0].name !== name ||
    mapping.version !== 0 ||
    mapping.data?.length !== 1 ||
    mapping.data[0].branchId !== branches[0].id ||
    mapping.data[0].clientKey !== 'true'
  )
    throw new Error(
      `Unsafe ${name} channel mapping; require one dedicated branch and no branch rollout.`,
    );
  return branches[0].id;
}
export function verifyRemoteGroup(updates, record, branch = 'staging') {
  if (!Array.isArray(updates) || updates.length !== 1)
    throw new Error('Expected exactly one Android update.');
  const update = updates[0];
  if (
    !uuid.test(update.id) ||
    !uuid.test(update.group) ||
    update.group !== record.groupId ||
    update.platform !== 'android' ||
    update.runtimeVersion !== record.runtimeVersion ||
    update.branch !== branch ||
    update.isRollBackToEmbedded ||
    update.gitCommitHash !== record.commitSha ||
    update.message !== updateMessage(record.commitSha, record.environmentHash)
  )
    throw new Error(
      'Update group does not match the validated staging artifact.',
    );
  return update;
}
export function normalizePublishedUpdates(updates) {
  if (!Array.isArray(updates))
    throw new Error('Unrecognized EAS publication response.');
  // EAS update emits normalized JSON; update:republish emits GraphQL fragments.
  return updates.map((item) => ({
    ...item,
    runtimeVersion: item.runtimeVersion ?? item.runtime?.version,
    branch: typeof item.branch === 'string' ? item.branch : item.branch?.name,
  }));
}
export function verifyStagingRecord(record, groupId) {
  if (
    record.schemaVersion !== 1 ||
    record.status !== 'published' ||
    record.channel !== 'staging' ||
    record.projectId !== easProject.id ||
    record.repository !== repository ||
    record.groupId !== groupId ||
    !uuid.test(groupId) ||
    !sha.test(record.commitSha) ||
    !sha.test(record.runtimeVersion) ||
    !sha256.test(record.environmentHash) ||
    !sha256.test(record.exportHash)
  )
    throw new Error('Invalid staging publication evidence.');
  return record;
}
export function rolloutPercentage(value, operation) {
  if (
    !/^\d{1,3}$/.test(String(value)) ||
    Number(value) < 1 ||
    Number(value) > 100
  )
    throw new Error('Rollout must be an integer between 1 and 100.');
  if (operation === 'rollback' && Number(value) !== 100)
    throw new Error(
      'An approved rollback must replace the faulty update for all users.',
    );
  return Number(value);
}
export const hashBytes = (bytes) =>
  createHash('sha256').update(bytes).digest('hex');
