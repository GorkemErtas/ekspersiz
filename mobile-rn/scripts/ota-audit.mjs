import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { easProject } from '../config/productionEnvironment.cjs';
import { repository } from './ota-guards.mjs';

export function recordBootstrapFailure(root, operation, env, commitSha) {
  if (!['staging', 'promote', 'rollback'].includes(operation))
    throw new Error('Unknown OTA audit operation.');
  const directory = join(root, '.ota/reports'),
    file = join(directory, 'publication.json');
  // Preserve success, a detailed validation error, or an ambiguous in-flight receipt.
  if (existsSync(file)) return false;
  mkdirSync(directory, { recursive: true });
  writeFileSync(
    file,
    JSON.stringify(
      {
        schemaVersion: 1,
        status: 'failed',
        phase: 'bootstrap',
        projectId: easProject.id,
        repository,
        operation,
        channel: operation === 'staging' ? 'staging' : 'production',
        commitSha,
        runId: env.GITHUB_RUN_ID,
        groupId: null,
        runtimeVersion: null,
        environmentHash: null,
        reason:
          'EAS bootstrap did not produce a publishing receipt; see this workflow run.',
      },
      null,
      2,
    ) + '\n',
    { flag: 'wx' },
  );
  return true;
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  recordBootstrapFailure(
    process.cwd(),
    process.argv[2],
    process.env,
    execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
  );
}
