import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { repository, rolloutPercentage, sha, uuid } from './ota-guards.mjs';

export async function githubGet(route, env, fetcher = fetch) {
  if (!env.GITHUB_TOKEN)
    throw new Error(
      'Read-only GitHub Actions token is required for provenance and approval checks.',
    );
  const response = await fetcher(
    `https://api.github.com/repos/${repository}/${route}`,
    {
      headers: {
        Authorization: `Bearer ${env.GITHUB_TOKEN}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      signal: AbortSignal.timeout(30000),
    },
  );
  if (!response.ok)
    throw new Error(
      `GitHub provenance/approval check failed (${response.status}).`,
    );
  return response.json();
}
export async function verifyApprovalEnvironment(env, fetcher = fetch) {
  const target = await githubGet('environments/ota-production', env, fetcher);
  if (
    target.name !== 'ota-production' ||
    !target.protection_rules?.some(
      (rule) =>
        rule.type === 'required_reviewers' && rule.reviewers?.length > 0,
    )
  )
    throw new Error(
      'ota-production must have required reviewers. Configure the protected environment before publishing.',
    );
  return true;
}
export function verifyStagingRun(run, workflow, runId) {
  if (
    !/^\d+$/.test(runId) ||
    String(run.id) !== runId ||
    run.repository?.full_name !== repository ||
    run.event !== 'push' ||
    run.head_branch !== 'master' ||
    !sha.test(run.head_sha) ||
    run.status !== 'completed' ||
    run.conclusion !== 'success' ||
    workflow.path !== '.github/workflows/mobile-rn-checks.yml' ||
    workflow.id !== run.workflow_id
  )
    throw new Error(
      'Source must be a successful master staging workflow in this repository.',
    );
  return run.head_sha;
}
export async function promotionProvenance(env, fetcher = fetch) {
  if (!['promote', 'rollback'].includes(env.OTA_OPERATION))
    throw new Error('Invalid production operation.');
  rolloutPercentage(env.OTA_ROLLOUT_PERCENTAGE, env.OTA_OPERATION);
  if (
    env.GITHUB_REPOSITORY !== repository ||
    env.GITHUB_REF !== 'refs/heads/master' ||
    env.GITHUB_EVENT_NAME !== 'workflow_dispatch' ||
    env.OTA_STAGING_VERIFIED !== 'true' ||
    !/^\d+$/.test(env.OTA_STAGING_RUN_ID ?? '') ||
    !uuid.test(env.OTA_UPDATE_GROUP_ID ?? '')
  )
    throw new Error('Production promotion requires explicit inputs on master.');
  await verifyApprovalEnvironment(env, fetcher);
  const run = await githubGet(
    `actions/runs/${env.OTA_STAGING_RUN_ID}`,
    env,
    fetcher,
  );
  const workflow = await githubGet(
    `actions/workflows/${run.workflow_id}`,
    env,
    fetcher,
  );
  const commitSha = verifyStagingRun(run, workflow, env.OTA_STAGING_RUN_ID);
  const artifactName = `ota-staging-${commitSha}`;
  const result = await githubGet(
    `actions/runs/${env.OTA_STAGING_RUN_ID}/artifacts?per_page=100`,
    env,
    fetcher,
  );
  const matches = result.artifacts?.filter(
    (item) => item.name === artifactName && !item.expired,
  );
  if (matches?.length !== 1)
    throw new Error('A unique, unexpired staging audit artifact is required.');
  return { commitSha, artifactName };
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const result = await promotionProvenance(process.env);
  if (!process.env.GITHUB_OUTPUT)
    throw new Error('This command is a GitHub Actions preflight.');
  appendFileSync(
    process.env.GITHUB_OUTPUT,
    `source_sha=${result.commitSha}\nartifact_name=${result.artifactName}\napproval_verified=true\n`,
  );
  console.log(
    `Validated staging provenance for ${result.commitSha}; production still requires environment approval.`,
  );
}
