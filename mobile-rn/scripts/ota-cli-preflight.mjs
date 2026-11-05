// Test-only harness for the installed CLI's real command and Expo config paths.
// All remote reads are synthetic; network, configuration writes and uploads are trapped.
import assert from 'node:assert/strict';
import { Buffer } from 'node:buffer';
import { createRequire } from 'node:module';
import {
  cpSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { firebase, publicEnv } from './ota-fixtures.mjs';
import {
  createPublicationSnapshot,
  sealPublicationSnapshot,
} from '../config/otaPublication.cjs';
import { productionEnvironmentConfig } from '../config/productionEnvironment.cjs';
import { inspectOtaExport } from './ota-bundle.mjs';

const source = process.cwd(),
  scenario = process.argv[2];
const cliRoot = process.env.OTA_EAS_CLI_ROOT;
assert.equal(
  JSON.parse(readFileSync(join(cliRoot, 'package.json'))).version,
  '27.2.0',
);
const require = createRequire(join(cliRoot, 'package.json'));
const load = (file) => require(join(cliRoot, 'build', file));
const stop = 'PREFLIGHT_STOP_BEFORE_UPLOAD';
const forbidden = () => {
  throw new Error('Forbidden network, write or publication in preflight');
};
load('fetch.js').default = forbidden;
for (const name of Object.keys(
  load('graphql/mutations/PublishMutation.js').PublishMutation,
))
  load('graphql/mutations/PublishMutation.js').PublishMutation[name] =
    forbidden;
const publish = load('project/publish.js');
publish.uploadAssetsAsync = forbidden;
publish.buildBundlesAsync = forbidden;
publish.resolveInputDirectoryAsync = async () => {
  throw new Error(stop);
};
publish.getBranchNameForCommandAsync = async () => 'staging';
load('update/configure.js').ensureEASUpdateIsConfiguredAsync = async () => {};
load('utils/statuspageService.js').maybeWarnAboutEasOutagesAsync =
  async () => {};
load('graphql/queries/AppQuery.js').AppQuery.byIdAsync = async () => ({
  ownerAccount: { name: 'trertas' },
  slug: 'ekspersiz-mobile',
});
const { Config } = require('@oclif/core');
const { default: Command } = load('commands/update/index.js');
const {
  DynamicPublicProjectConfigContextField,
  DynamicPrivateProjectConfigContextField,
} = load('commandUtils/context/DynamicProjectConfigContextField.js');
const { ServerSideEnvironmentVariablesContextField } = load(
  'commandUtils/context/ServerSideEnvironmentVariablesContextField.js',
);
const prefix = join(tmpdir(), 'ekspersiz-ota-cli-'),
  root = mkdtempSync(prefix);
let linked = false;
try {
  for (const file of ['app.config.ts', 'package.json', 'eas.json'])
    cpSync(join(source, file), join(root, file));
  for (const folder of ['config', 'plugins'])
    cpSync(join(source, folder), join(root, folder), { recursive: true });
  symlinkSync(
    join(source, 'node_modules'),
    join(root, 'node_modules'),
    process.platform === 'win32' ? 'junction' : 'dir',
  );
  linked = true;
  mkdirSync(join(root, '.ota/export'), { recursive: true });
  mkdirSync(join(root, 'secrets'));
  const bytes = JSON.stringify(firebase());
  writeFileSync(join(root, 'secrets/google-services.production.json'), bytes);
  for (const name of Object.keys(process.env))
    if (
      /^(APP_|ANDROID_|EXPO_|GOOGLE_|IOS_|EAS_|GITHUB_)/.test(name) ||
      name === 'CI'
    )
      delete process.env[name];
  Object.assign(
    process.env,
    publicEnv('./secrets/google-services.production.json'),
    { GOOGLE_SERVICES_JSON_BASE64: Buffer.from(bytes).toString('base64') },
  );
  const initial = { ...process.env };
  const { environmentHash } = productionEnvironmentConfig(initial, root);
  createPublicationSnapshot(initial, root, {
    environmentHash,
    runtimeVersion: 'a'.repeat(40),
  });
  const output = join(root, '.ota/export');
  writeFileSync(
    join(output, 'metadata.json'),
    JSON.stringify({
      bundler: 'metro',
      fileMetadata: { android: { bundle: 'bundle.hbc' } },
    }),
  );
  writeFileSync(
    join(output, 'bundle.hbc'),
    Buffer.from('c61fbc03c103191f', 'hex'),
  );
  writeFileSync(
    join(output, 'bundle.hbc.map'),
    JSON.stringify({ sources: ['src/app.tsx'] }),
  );
  sealPublicationSnapshot(initial, root, inspectOtaExport(output, {}));
  if (scenario === 'bundle-drift')
    writeFileSync(join(output, 'bundle.hbc'), 'modified');
  if (scenario === 'missing-ci') process.env.CI = '1';
  if (scenario === 'missing-eas-build') process.env.EAS_BUILD = '1';
  if (scenario === 'missing-github') process.env.GITHUB_ACTIONS = 'true';
  const remote = {
    ...publicEnv('./secrets/google-services.production.json'),
    GOOGLE_SERVICES_JSON_BASE64: initial.GOOGLE_SERVICES_JSON_BASE64,
  };
  if (scenario === 'public-drift')
    remote.EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY = 'goog_changed';
  if (scenario === 'firebase-drift')
    remote.GOOGLE_SERVICES_JSON_BASE64 = Buffer.from(bytes + '\n').toString(
      'base64',
    );
  if (scenario === 'variant-drift')
    Object.assign(remote, {
      APP_VARIANT: 'development',
      APP_CONFIG_MODE: 'native',
    });
  let reads = 0;
  load(
    'graphql/queries/EnvironmentVariablesQuery.js',
  ).EnvironmentVariablesQuery.byAppIdWithSensitiveAsync = async () => {
    reads++;
    if (scenario === 'server-failure')
      throw new Error('Synthetic EAS environment fetch failed');
    return Object.entries(remote).map(([name, value]) => ({ name, value }));
  };
  process.chdir(root);
  const args = [
    '--channel',
    'staging',
    '--platform',
    'android',
    '--skip-bundler',
    '--input-dir',
    '.ota/export',
    '--message',
    'preflight-only',
    '--non-interactive',
  ];
  if (!scenario.startsWith('missing-'))
    args.push('--environment', 'production');
  const command = new Command(args, await Config.load({ root: cliRoot }));
  const sessionManager = {
    ensureLoggedInAsync: async () => ({
      actor: {},
      authenticationInfo: { accessToken: 'synthetic-unused' },
    }),
    getGraphqlClient: () => ({}),
  };
  command.getContextAsync = async (_, options) => {
    const context = { ...options, sessionManager };
    return {
      getDynamicPublicProjectConfigAsync:
        await new DynamicPublicProjectConfigContextField().getValueAsync(
          context,
        ),
      getDynamicPrivateProjectConfigAsync:
        await new DynamicPrivateProjectConfigContextField().getValueAsync(
          context,
        ),
      getServerSideEnvironmentVariablesAsync:
        await new ServerSideEnvironmentVariablesContextField().getValueAsync(
          context,
        ),
      loggedIn: { graphqlClient: {} },
      vcsClient: {
        ensureRepoExistsAsync: async () => {},
        isCommitRequiredAsync: async () => false,
        hasUncommittedChangesAsync: async () => false,
      },
    };
  };
  let error;
  try {
    await command.runAsync();
  } catch (caught) {
    error = [caught.message, caught.stderr, caught.stdout]
      .filter(Boolean)
      .join('\n');
  }
  const expected = {
    'missing-local': /--environment.*must be set/,
    'missing-github': /--environment.*must be set/,
    'missing-ci': /PREFLIGHT_STOP_BEFORE_UPLOAD/,
    'missing-eas-build': /PREFLIGHT_STOP_BEFORE_UPLOAD/,
    valid: /PREFLIGHT_STOP_BEFORE_UPLOAD/,
    'public-drift': /configuration drift/,
    'firebase-drift': /configuration drift/,
    'variant-drift': /configuration drift/,
    'bundle-drift': /bundle drift/,
    'server-failure': /Synthetic EAS environment fetch failed/,
  }[scenario];
  assert.ok(expected, 'Unknown preflight scenario');
  assert.match(error ?? '', expected);
  assert.equal(
    reads,
    scenario.startsWith('missing-') || scenario === 'bundle-drift' ? 0 : 1,
  );
  console.log(
    JSON.stringify({
      scenario,
      cli: '27.2.0',
      environmentReads: reads,
      stoppedBeforeUpload: true,
    }),
  );
} finally {
  process.chdir(source);
  assert.ok(resolve(root).startsWith(resolve(prefix)));
  if (linked) unlinkSync(join(root, 'node_modules'));
  rmSync(root, {
    recursive: true,
    force: true,
    maxRetries: 10,
    retryDelay: 100,
  });
}
