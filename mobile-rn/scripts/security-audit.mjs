import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// Temporary tooling exception, reviewed in docs/production/READINESS_AUDIT.md.
// Never accept new advisories or silently use npm audit fix --force.
const acceptedUrl = 'https://github.com/advisories/GHSA-mrhx-c7xc-m3w5';
const toolingPackages = new Set(['zod', '@expo/cli', 'expo']);
export function evaluateAudit(report, now = new Date()) {
  if (
    report?.error ||
    report?.auditReportVersion !== 2 ||
    !report.vulnerabilities ||
    !report.metadata?.vulnerabilities
  )
    throw new Error('npm audit did not return a valid registry report.');
  const accepted = [],
    blocked = [];
  const knownChain = (name, visited = new Set()) => {
    if (visited.has(name) || !toolingPackages.has(name)) return false;
    visited.add(name);
    const vulnerability = report.vulnerabilities[name];
    return vulnerability?.via?.some((via) =>
      typeof via === 'string'
        ? knownChain(via, visited)
        : via.url === acceptedUrl &&
          via.name === 'zod' &&
          via.severity === 'high',
    );
  };
  for (const [name, finding] of Object.entries(report.vulnerabilities)) {
    if (!['high', 'critical'].includes(finding.severity)) continue;
    const unknownAdvisory = finding.via.some(
      (via) =>
        typeof via !== 'string' &&
        ['high', 'critical'].includes(via.severity) &&
        via.url !== acceptedUrl,
    );
    if (
      finding.severity === 'high' &&
      !unknownAdvisory &&
      knownChain(name) &&
      now < new Date('2026-11-30T00:00:00Z')
    )
      accepted.push(name);
    else blocked.push(name);
  }
  return { accepted, blocked, counts: report.metadata.vulnerabilities };
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    if (!process.env.npm_execpath)
      throw new Error('Run through npm run audit:ci.');
    const registry = spawnSync(
      process.execPath,
      [process.env.npm_execpath, 'ping'],
      {
        encoding: 'utf8',
        timeout: 30_000,
      },
    );
    if (registry.error || registry.status !== 0)
      throw new Error(
        'npm registry is unreachable; a clean audit cannot be asserted.',
      );
    const result = spawnSync(
      process.execPath,
      [process.env.npm_execpath, 'audit', '--json'],
      { encoding: 'utf8', timeout: 120_000, maxBuffer: 10 * 1024 * 1024 },
    );
    if (result.error || ![0, 1].includes(result.status))
      throw new Error(
        result.error?.message ?? result.stderr ?? 'npm audit failed.',
      );
    const report = JSON.parse(result.stdout);
    const decision = evaluateAudit(report);
    mkdirSync('coverage', { recursive: true });
    writeFileSync(
      'coverage/npm-audit.json',
      JSON.stringify({ report, decision }, null, 2),
    );
    console.log(JSON.stringify(decision, null, 2));
    if (decision.blocked.length) process.exitCode = 1;
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
