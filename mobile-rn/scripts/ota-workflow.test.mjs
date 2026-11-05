import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { load: parse } = require('js-yaml');
const readiness = parse(
  readFileSync('../.github/workflows/mobile-rn-checks.yml', 'utf8'),
);
const promotion = parse(
  readFileSync('../.github/workflows/mobile-ota-promote.yml', 'utf8'),
);
const eas = JSON.parse(readFileSync('eas.json', 'utf8'));

test('automatic staging cannot run from PRs, feature branches, failed checks or native changes', () => {
  assert.ok(readiness.on.pull_request);
  assert.equal(readiness.on.pull_request_target, undefined);
  assert.deepEqual(readiness.on.push.branches, ['master']);
  const job = readiness.jobs.staging;
  for (const gate of [
    "github.event_name == 'push'",
    "github.ref == 'refs/heads/master'",
    "github.repository == 'GorkemErtas/ekspersiz'",
    "needs.classify.outputs.kind == 'ota'",
    "needs.checks.result == 'success'",
    "needs.compatibility.result == 'success'",
    "vars.OTA_STAGING_ENABLED == 'true'",
  ])
    assert.ok(job.if.includes(gate), gate);
  assert.deepEqual(job.needs, ['classify', 'checks', 'compatibility']);
  assert.equal(job.environment, 'ota-staging');
  assert.equal(readiness.permissions.contents, 'read');
  for (const name of ['checks', 'android', 'compatibility', 'classify'])
    assert.doesNotMatch(
      JSON.stringify(readiness.jobs[name]),
      /secrets\.EXPO_TOKEN/,
    );
  assert.equal(job.env?.EXPO_TOKEN, undefined);
  assert.ok(readiness.jobs.android.if.includes("kind == 'native'"));
  assert.ok(
    readiness.jobs.compatibility.steps.some((step) =>
      step.run?.includes('ota-fingerprint.mjs mobile-rn baseline/mobile-rn'),
    ),
  );
});
test('production is manual, protected, serial and promotes the original successful staging artifact', () => {
  assert.deepEqual(Object.keys(promotion.on), ['workflow_dispatch']);
  assert.equal(
    promotion.on.workflow_dispatch.inputs.staging_verified.default,
    false,
  );
  assert.equal(promotion.jobs.production.environment, 'ota-production');
  assert.equal(promotion.concurrency['cancel-in-progress'], false);
  assert.deepEqual(promotion.permissions, {
    contents: 'read',
    actions: 'read',
  });
  const steps = promotion.jobs.production.steps;
  const checkout = steps.find((step) =>
    step.uses?.startsWith('actions/checkout@'),
  );
  assert.equal(checkout.with.ref, '${{ needs.provenance.outputs.source_sha }}');
  const download = steps.find((step) =>
    step.uses?.startsWith('actions/download-artifact@'),
  );
  assert.equal(
    download.with.name,
    '${{ needs.provenance.outputs.artifact_name }}',
  );
  assert.equal(download.with['run-id'], '${{ inputs.staging_run_id }}');
  assert.equal(
    promotion.jobs.production.env.OTA_APPROVAL_VERIFIED,
    '${{ needs.provenance.outputs.approval_verified }}',
  );
  assert.doesNotMatch(
    steps.map((step) => step.run ?? '').join('\n'),
    /expo export|gradlew|eas build|eas submit|eas update --channel production/,
  );
  for (const step of steps)
    if (step.run) assert.doesNotMatch(step.run, /\$\{\{\s*inputs\./);
});
test('EAS is pinned and audit uploads cannot include public exports, private metadata or signing files', () => {
  for (const workflow of [readiness, promotion]) {
    const jobs = Object.values(workflow.jobs).filter((job) => job.environment);
    for (const job of jobs) {
      assert.ok(
        job.steps.some(
          (step) =>
            step.run === `npm install --global eas-cli@${eas.cli.version}`,
        ),
      );
      const upload = job.steps.find((step) =>
        step.uses?.startsWith('actions/upload-artifact@'),
      );
      assert.equal(upload.with.path, 'mobile-rn/.ota/reports/publication.json');
      assert.equal(upload.with['include-hidden-files'], true);
    }
  }
  assert.equal(eas.cli.requireCommit, true);
  assert.equal(eas.build, undefined); // Local signed native releases remain the only production build path.
  const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
  const lock = JSON.parse(readFileSync('package-lock.json', 'utf8'));
  assert.ok(pkg.dependencies['expo-updates']);
  assert.equal(
    pkg.dependencies['expo-updates'],
    lock.packages[''].dependencies['expo-updates'],
  );
});
