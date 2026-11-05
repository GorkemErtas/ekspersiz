# EksperSiz Android OTA updates and CI/CD

Status on 5 November 2026: infrastructure implemented; production publishing is **not enabled or verified**. External setup, accepted OTA-enabled native binaries and device verification are still required. No update was published, no production AAB was generated or uploaded, and no live Play application was changed during this work.

## Verified state and corrections to the earlier runbook

- Existing EAS project verified read-only: `@trertas/ekspersiz-mobile`, ID `883c68ec-f7e4-4c3e-87e2-e989c4b4b859`. Ownership and ID are unchanged. Do not run `eas init` or link a new project.
- `expo-updates` **58.0.20** was already installed and locked. Expo 58.0.21, React Native 0.88.1 and all native dependencies are unchanged; no package reinstall or SDK upgrade was needed for integration.
- The existing EAS `staging` channel points to the `staging` branch. A production channel was not listed. The new publisher verifies both mappings before any publication and never creates or relinks them implicitly.
- GitHub currently lists two existing deployment environments, neither named `ota-staging` or `ota-production`. The required OTA environment protection and tokens still need owner setup. No environment or secret was modified.
- The historical local production APK `1.0.2 (54)` was inspected with Android build-tools: `expo.modules.updates.ENABLED=false`, no update URL, runtime or channel. SHA-256: `3376e9a58b85cd2ec6262ec7362b13ea26873d93c58657c59d6bf236f81bf1f7`.
- That historical APK is **not evidence of the currently installed Play binary**. No device is connected. The [release notes](ANDROID_RELEASE.md) contain an owner-reported version 59 from 4 November; neither 54 nor 59 is a verified current maximum. Check every Play track and draft again before a native release.

The earlier document incorrectly said the Expo project and `expo-updates` were missing. Its manual `eas update` commands also required private native signing inputs through `app.config.ts`. Both inconsistencies are addressed.

## Architecture and compatibility

`config/productionEnvironment.cjs` validates the production identity, exact existing HTTPS API, Android public SDK keys, Firebase Android client/web OAuth binding, explicit dotenv isolation and native version metadata. It calculates a SHA-256 public-environment digest. Private service-account JSON and unexpected `EXPO_PUBLIC_*` variables are rejected.

`APP_CONFIG_MODE=native` remains the default. `androidReleaseConfig` adds the existing Play SHA-1/SHA-256, versionCode greater than the operator-verified Play maximum, and original upload-key/property-file requirements. Native release scripts force native mode; the production Gradle config plugin rejects OTA evaluation mode during native generation. Existing signing, R8/constructor, Hermes, permissions and ABI checks remain in place.

`APP_CONFIG_MODE=ota` evaluates the same production public configuration without requiring a private keystore, signing properties, Play certificate inputs or a new versionCode. Signing credentials are rejected in the OTA environment. Firebase **client** JSON and existing native version metadata are still needed for compatibility; they are not Android signing credentials.

OTA is explicitly disabled when not opted in: `updates.enabled=false`. Enabling it requires `EXPO_UPDATES_ENABLED=1`, the exact registered project ID, a staging/production channel, production identity/environment and installed `expo-updates`. Invalid or partial opt-in configuration throws instead of falling back to development.

### Runtime policy decision

The old runtime was Android `versionName` alone. That can accidentally target an old binary when native dependencies change without a versionName bump. The new runtime is Expo's `{ "policy": "fingerprint" }`, with the installed Expo fingerprint implementation and extra fail-closed checks:

- Native library and config-plugin **files**, CNG configuration, native assets, local modules and `src/platform` bridge contracts contribute to the hash. Missing Expo/RN autolinking graphs fail validation.
- The only delivery normalization is the value of `updates.requestHeaders['expo-channel-name']`. Channel routing is not a native ABI difference. All other configuration, including project/package identity and the production public-environment digest, stays in the fingerprint.
- Version fields use Expo's balanced-policy exclusions. Staging and production require different Play versionCodes but can have the same ABI/runtime. Keep matching versionNames and public environment values for both channel binaries. OTA does not increment Play versionCode.
- Native inputs use LF line endings through `.gitattributes`. Use a clean checkout with the committed attributes for native builds and CI; do not fingerprint stale generated/modified native sources. The pipeline supports this repository's CNG workflow and rejects tracked root `android/` or `ios/` projects.
- A real regression test compares the publishing hash with **the SDK's runtime resolver**, verifies equality across channels, verifies UI-only changes leave it unchanged, and verifies native changes change it.

Expo currently also documents appVersion as a simpler policy. Fingerprint is chosen here for automatic native-change detection; its operational risks are addressed by pinning SDK/CLI, testing the actual resolver, conservative path classification, and requiring verified binary evidence. It is not an authorization mechanism.

`ota/native-runtimes.json` starts with an **empty** catalog. There is no fabricated native baseline. Staging needs an accepted staging binary. Production promotion additionally needs an accepted production binary with the same runtime/environment and versionName, and a different valid Play versionCode. Never fill this catalog using a guessed hash or a JS export alone.

## One-time owner setup

### 1. EAS identity, CLI and channels

The supported CLI is pinned to **27.2.0** in `mobile-rn/eas.json` and CI. `eas.json` has no production cloud-build profile: existing locally signed native releases remain the production build path.

```powershell
cd mobile-rn
eas --version
eas project:info
eas channel:view staging --json
# Only create missing resources after owner review. These commands do not publish a bundle:
eas branch:create production --non-interactive
eas channel:create production --branch production --non-interactive
eas channel:view production --json
```

Do not recreate existing branches/channels. Require one distinct branch per channel, matching names, with no branch rollout or unexpected routing. The guarded publisher rejects paused or ambiguous channel mappings; resolve an intentional incident pause/routing change through owner review before normal deployment. Update-group progressive rollouts are separate from channel/branch routing.

### 2. EAS production environment

Use **one EAS environment named `production` for both update channels**. This makes the staged artifact suitable for promotion to production. Configure the following using the Expo dashboard or reviewed `eas env:create`/`eas env:update` commands:

| Variable                                       | Required value/source                                                                                                              |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `APP_VARIANT`                                  | `production`                                                                                                                       |
| `APP_CONFIG_MODE`                              | `ota`                                                                                                                              |
| `EXPO_NO_DOTENV`                               | `1`                                                                                                                                |
| `EXPO_UPDATES_ENABLED`                         | `1`                                                                                                                                |
| `EXPO_UPDATES_PROJECT_ID`                      | `883c68ec-f7e4-4c3e-87e2-e989c4b4b859`                                                                                             |
| `EXPO_PUBLIC_API_BASE_URL`                     | `https://ekspersiz-backend-production.up.railway.app/api/v1`                                                                       |
| `EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID`             | Existing production web/server OAuth client, matching Firebase type 3                                                              |
| `EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY`      | Existing Android-restricted Maps SDK public key                                                                                    |
| `EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY`    | Existing Android `goog_` public key; never `test_` or a secret API key                                                             |
| `GOOGLE_SERVICES_FILE`                         | Exactly `./secrets/google-services.production.json`                                                                                |
| `GOOGLE_SERVICES_JSON_BASE64`                  | Base64 of the exact same production Android **client JSON bytes** used in the native release; visibility **Sensitive**, not Secret |
| `ANDROID_VERSION_NAME`, `ANDROID_VERSION_CODE` | Reviewed metadata for the compatible native release; no OTA versionCode increment                                                  |

The client JSON is already embedded in Android binaries. It is not Firebase Admin/service-account JSON. Use identical bytes and the canonical relative path in local native builds and CI. A conflicting local file is never overwritten. Sensitive EAS values can be loaded by `env:exec`; secret-visibility values are not locally readable and must not be relied on for OTA export.

Do not put channel, GitHub control variables or signing inputs in this shared EAS environment. The guarded command chooses the channel from the workflow operation. Never upload `key.properties`, `.jks`, keystore passwords, Google service-account keys, Gemini keys, backend secrets or RevenueCat secret keys. `.easignore` provides an additional archive exclusion; native production builds do not use Expo Build or upload the signing identity.

Staging explicitly uses `eas update --environment production --skip-bundler`. Although CLI 27.2.0 skips its SDK 55+ missing-flag check when `CI` or `EAS_BUILD` is nonempty, deployment does not rely on that exception. Outside those contexts, a missing flag in non-interactive mode throws; `GITHUB_ACTIONS` alone does not bypass it. `eas env:exec` only loads variables and does not supply an update flag.

The outer `eas env:exec production` provides the values validated and exported by the guarded publisher. Before exporting, it creates a local `.ota/publication-snapshot.json` containing only digests and the expected native runtime. After export validation it seals the exact export digest. `app.config.ts` checks that file on **every** evaluation, before choosing even the app variant. Any changed effective configuration input, public-environment hash, Firebase client bytes/base64/path, channel or sealed export fails closed. Native fingerprints are compared before export, after export and immediately before starting the publishing CLI. The snapshot guard also applies to the CLI/SDK's later config evaluations during runtime resolution; returned update runtime/source identity must match the receipt.

With `--environment`, the pinned CLI fetches the production environment again and caches it for that command. This second read is intentional: unchanged effective values are accepted; changed values are rejected before uploading rather than silently publishing the earlier bundle with different metadata/runtime. Production republishing and rollback still reuse the existing group without exporting. Normal completion/failure removes the temporary snapshot and preserves the audit receipt. After an abruptly killed process, inspect the audit/Expo state before removing a stale snapshot and retrying; never bypass the guard or auto-retry an ambiguous publication.

### 3. GitHub protection and credentials

Create:

- `ota-staging`: restrict deployment branches to `master`; automatic staging approval can be omitted. Add an environment secret named `EXPO_TOKEN`.
- `ota-production`: restrict deployments to `master` and configure **required reviewers**. Add its own environment secret named `EXPO_TOKEN`. Production preflight queries GitHub's API and fails if required reviewers are absent or cannot be verified; naming an environment alone is insufficient.
- Repository variable `OTA_STAGING_ENABLED=true` **only after** native staging migration, runtime registration and external setup have passed acceptance. Until then leave it unset/false.

Use a dedicated Expo access token with only the permissions needed on the existing account/project to read configuration and publish updates. Expo personal tokens inherit their user's access; they are not magically channel-scoped. If the existing owner/account supports a suitable robot user, use the least privileged publishing role. Do not transfer the project or create a new Expo project to configure credentials. Keep tokens only in the two protected environment secrets, not public variables, repo files, artifacts or PR validation jobs.

`GITHUB_TOKEN` is supplied by GitHub with `contents: read` and, for promotion provenance, `actions: read`. No repository-write, signing or Play submission credential is needed. Protect master and require the readiness/classification/compatibility checks and review of workflow, fingerprint and runtime-catalog changes.

### 4. Verify and migrate native binaries

First inspect the **actual installed Play package**, not an unrelated old local APK:

```powershell
adb devices -l
adb -s SERIAL shell pm path com.gorkem.ekspersiz
# Pull the exact base.apk path returned above:
adb -s SERIAL pull /actual/path/base.apk .ota/play-installed.apk
npm run ota:inspect -- .ota/play-installed.apk
```

With Expo SDK 58, `file:fingerprint` in the compiled runtime string is an expected SDK sentinel. Android resolves it by reading the exact `assets/fingerprint` entry inside the APK. The inspector follows that same path and reports the effective 40-character runtime; Java 21 must be available through `JAVA_HOME` or `PATH`. Missing, duplicate or malformed fingerprint assets fail inspection. Do not replace the sentinel in generated resources or accept it as the runtime itself.

If it is not OTA-enabled with this project/channel/fingerprint runtime, it cannot receive these updates. A one-time native migration is mandatory.

**Only after explicit native release authorization:** follow [ANDROID_RELEASE.md](ANDROID_RELEASE.md), verify the current maximum across **all** Play tracks/drafts, reuse the original upload key, and fill the ignored local release environment. The template no longer includes stale numeric version defaults. For staging, use:

```dotenv
APP_VARIANT=production
APP_CONFIG_MODE=native
EXPO_UPDATES_ENABLED=1
EXPO_UPDATES_PROJECT_ID=883c68ec-f7e4-4c3e-87e2-e989c4b4b859
EXPO_UPDATES_CHANNEL=staging
GOOGLE_SERVICES_FILE=./secrets/google-services.production.json
```

The other signing/API/Google/Play/version values remain required by the existing native preflight. In a clean, authorized native release checkout:

```powershell
npm run release:check
# Produces signed native artifacts only with explicit release authorization:
npm run release:android -- --apk
```

OTA-enabled native releases require the companion APK so its **compiled** metadata can be checked. The script verifies its embedded project, channel, exact fingerprint runtime and startup policy; the existing APK/AAB DEX, signature, R8/Hermes and ABI checks remain. The release verification JSON includes the OTA environment digest and source commit. Do not generate a new key or send the private key to EAS.

The native preflight uses the installed `expo-updates` managed runtime resolver, as EAS Update does, and still requires complete config/autolinking/native-bridge fingerprint sources. It passes that newly calculated runtime to Gradle through Expo's `EXPO_UPDATES_FINGERPRINT_OVERRIDE`, matching EAS Build's Android flow. Inherited fingerprint/workflow overrides are discarded; no fixed hash belongs in the release environment file. The SDK update-resources task is explicitly rerun because this SDK version does not declare the override environment as a Gradle task input. The SDK packages the resolved hash as `assets/fingerprint`, and the release verifier compares the APK asset with the preflight result before completing the AAB/verification receipt copies. The `runtimeVersion: { policy: 'fingerprint' }` configuration and channel normalization remain in place.

To rebuild after this tooling fix, run the two commands above from `mobile-rn` with the existing validated `.env.production.local`. No manual native-resource edit, dependency reinstall or OTA publication is required. A successful release records the effective runtime at `apk.ota.runtimeVersion` in `release-artifacts/ekspersiz-<versionName>-<versionCode>-verification.json`.

Distribute the staging AAB through the authorized Play internal-test process and verify startup, offline launch, authentication, FCM, analysis, forms, credits and billing on real test devices/accounts. An upload-key-signed APK alone is not proof of Google Play App Signing or Play Integrity behavior. Inspect the installed Play APK and confirm its channel/runtime. Use a dedicated staging test device: staging and production have the same package ID and cannot be installed side by side.

Register accepted staging binary evidence in `ota/native-runtimes.json` through a reviewed commit. A record has this shape (placeholders must come from actual verification; never copy these as working values):

```json
{
  "runtimeVersion": "<40-hex Expo fingerprint embedded in APK>",
  "environmentHash": "<64-hex production public-environment digest>",
  "sourceCommit": "<40-hex ancestor commit used for the native build>",
  "verified": true,
  "binaries": {
    "staging": {
      "sha256": "<inspected APK SHA-256>",
      "versionCode": 0,
      "versionName": "<x.y.z>"
    }
  }
}
```

`versionCode: 0` above is deliberately invalid. Use the real accepted native value. Do not claim a device acceptance that has not happened. Preserve release verification/AAB identity records alongside the catalog's APK evidence.

After staging verification and explicit authorization for production native migration, build a production-channel binary from the same native source/public environment and versionName, with its own newly verified higher Play versionCode. Complete the existing production release approval and Play rollout procedure. Add the inspected production binary under `binaries.production`, using the same record/runtime. Promotion remains blocked until both binaries are verified and compatible. No automation submits either AAB to Play.

Promotion reads the native catalog from the staging artifact's exact source commit. An initial staging-only bootstrap receipt cannot later acquire production evidence. After both binaries are registered on master, use the next validated compatible JS change to create a new staging receipt for production acceptance; do not try to promote the earlier bootstrap receipt.

## Automatic staging workflow

`.github/workflows/mobile-rn-checks.yml` performs:

1. Conservative classification of every changed path, including both sides of renames. Known screens/components/application JS/TS and compatible images are OTA candidates. Native dependencies/lockfile, Expo config, plugins, permissions, native modules/bridges, branding, workflow/policy files and unknown mobile inputs require native/manual review. Docs/tests alone do not publish updates.
2. TypeScript, ESLint, Jest, release/OTA script tests, config validation, locked-SDK compatibility, both development-platform exports, runtime-source scanning and the existing security audit.
3. For OTA candidates, separate clean installs and real native fingerprint comparison between the base and candidate. Fingerprint computation must include Expo and RN autolinking and native bridge contracts; unknown/incomplete compatibility fails closed.
4. Native `.dev` debug and optimized release smoke builds only for native/manual changes or an explicit readiness dispatch. These are not production-signed artifacts. OTA candidates skip these expensive native jobs.
5. After a **master push only**, an opted-in `ota-staging` job loads the canonical EAS production environment, checks the verified native catalog, exports Android once, checks Hermes bytecode/source maps/private-file and credential exclusions, and publishes to staging with the bundle step skipped. No signing or Play credential is provided.

An immutable 90-day audit artifact records repository, commit SHA, runtime, environment/export digests, update/group IDs, channel, run ID and result. The update message also binds the source SHA and environment digest. Failed/ambiguous publication attempts are recorded and are never automatically retried or rolled back. Inspect Expo before retrying after a lost response.

Master publication runs are serialized and not canceled by later pushes. PR checks can cancel superseded runs. No PR validation receives `EXPO_TOKEN`.

For native/manual classification, the run summary lists the affected files and directs the operator to the existing native release procedure. No OTA is published automatically for that merge. If the actual fingerprint changes, accept a new compatible native binary before that runtime can publish. Review-only tooling changes can leave the native runtime unchanged; they still do not auto-publish themselves.

## Manual production promotion and rollback

After testing the exact staging group on compatible devices, use its successful **master** readiness/staging run ID and recorded group ID:

```powershell
gh workflow run mobile-ota-promote.yml --ref master -f operation=promote -f staging_run_id=RUN_ID -f update_group_id=STAGING_GROUP_UUID -f staging_verified=true -f rollout_percentage=10
```

Approve the `ota-production` environment deployment in GitHub. The workflow:

- Verifies the source run belongs to this repository's readiness workflow, succeeded on a master push, and has a unique unexpired staging audit artifact.
- Checks out that artifact's exact source SHA, loads the same production public environment, verifies approved native binaries and the environment/runtime digest, and compares the actual Expo staging group with the audit record.
- Uses `eas update:republish --group ... --destination-channel production`, **without exporting or rebuilding**. Both normalized publication JSON and the pinned CLI's GraphQL republish response are covered by tests.
- Records the new production group/update IDs, original staging group, source/export/runtime/environment identity, rollout and result. Production cannot share the staging branch or run without required-reviewer protection.

A rollout percentage must be an integer from 1 to 100. Default promotion is 10 percent. Observe that group before expanding it. Read-only inspection commands:

```powershell
eas update:view PRODUCTION_GROUP_UUID --json
eas update:view PRODUCTION_GROUP_UUID --insights --days 7
eas channel:view production --json
```

Use the Expo dashboard/CLI to review launches, adoption and failures when those metrics are available on the account. A successful publish is not proof of adoption, correctness or real payment/AI flows. Expansion of an active rollout is a separate explicitly approved owner operation; for the pinned CLI:

```powershell
eas update:edit PRODUCTION_GROUP_UUID --rollout-percentage 100 --non-interactive
```

Do not start another normal release over an unresolved active rollout. Do not automatically roll back from unverified signals.

For a faulty update, identify the affected production group/runtime/channel and select the previous accepted staging artifact for the **same compatible runtime and public environment**. Then request explicit rollback approval:

```powershell
gh workflow run mobile-ota-promote.yml --ref master -f operation=rollback -f staging_run_id=PREVIOUS_GOOD_RUN_ID -f update_group_id=PREVIOUS_GOOD_STAGING_GROUP_UUID -f staging_verified=true -f rollout_percentage=100
```

The same provenance, native compatibility and environment-reviewer checks apply. Rollback republishes the prior artifact at 100 percent and explicitly supersedes an active rollout; it never rebuilds old source or infers a good version automatically. Devices receive it through the normal update lifecycle. It cannot fix native initialization failures in a binary that cannot start updates.

Keep accepted publication receipts beyond GitHub's artifact retention if an older rollback may be needed. Expired/missing audit artifacts deliberately block the automated workflow. For a break-glass rollback, the owner must separately approve and record the previous Expo group/source SHA/runtime/environment and native compatibility before a direct controlled `eas update:republish`; do not substitute a fresh unverified `eas update`. Refer to Expo's error-recovery/rollback guidance for an approved rollback to the embedded bundle.

## Application lifecycle

There is no custom reload timer, foreground listener or `reloadAsync` call. Native `ON_LOAD` checking with zero launch wait starts the available embedded/cached bundle, downloads compatible updates opportunistically and activates a fully downloaded update on a subsequent cold launch. It does not restart an active analysis, payment/credit operation or form session. Offline/interrupted downloads retain the usable embedded/cached version. Embedded updates and Expo anti-bricking/error-recovery mechanisms stay enabled. Existing Hermes, splash, auth bootstrap and navigation code is untouched.

## Verification and troubleshooting

```powershell
cd mobile-rn
npm run typecheck
npm run lint
npm test -- --ci
npm run test:ci-scripts
npm install --global eas-cli@27.2.0
npm run test:ota-cli
npm run check:config
npm run audit:ci
npm run format:check
$env:EXPO_NO_DOTENV = '1'
$env:EXPO_OFFLINE = '1'
npx expo install --check
```

For read-only OTA preflight, use a clean OTA shell without signing variables, bootstrap project lookup in development mode, then load EAS's production environment:

```powershell
$env:APP_VARIANT = 'development'
$env:APP_CONFIG_MODE = 'native'
$env:EXPO_NO_DOTENV = '1'
eas env:exec production 'npm run ota:check' --non-interactive
```

This validates the public environment and registered staging runtime; it does not publish. A pending/empty catalog is an expected NO-GO until native acceptance is complete.

Common failures:

- Missing project/channel, invalid public key/API, missing production environment: fix explicit configuration. Never use `.env.local`, a fixture endpoint or a test RevenueCat key to make publishing pass.
- Missing/incomplete autolinking: fix dependency installation/subprocess access; do not accept a partial fingerprint.
- Runtime mismatch: compare native source, plugins, SDK/dependencies, canonical Firebase path/content, public values and line endings. Use a clean LF checkout. Do not edit a runtime string just to force compatibility.
- Unregistered runtime: authorize/verify the required native migration and register real evidence; do not fabricate catalog entries or signing files.
- Different staging/production environment: test a newly exported staging artifact for that environment before promotion.
- Snapshot/configuration/bundle drift: the explicit EAS environment differed from the validated export, or an input changed. Correct the canonical environment and rerun validation/export; do not edit a snapshot or remove validation to force publication.
- Missing reviewers, missing/expired artifact, failed source run, wrong group or branch mapping: fail closed and correct/review the source evidence or external protection.
- Interrupted publish or `unconfirmed` result: inspect the exact commit-bound Expo group before retrying. There is no automatic retry or rollback.

The [OTA validation report](OTA_VALIDATION.md) records checks performed for this change and their practical limits. Native iOS OTA release, currently installed Play capability/adoption, real-store/AI/auth behavior, offline recovery and interrupted downloads on signed migration binaries still require their own device acceptance. A local JS export or synthetic test is not proof of a live production OTA deployment.

## Build frequency and cost

Compatible JS/UI/asset updates use EAS Update and avoid a new AAB and the native CI matrix. Changed native fingerprints require new accepted native binaries; unknown inputs require review instead of speculative publishing. Package caching, classification and skipping native jobs reduce routine Actions/native-build work. EAS Update still has account MAU/bandwidth/plan limits; inspect usage and current pricing rather than assuming unlimited or free delivery. This change does not select a paid plan or alter billing.

## Primary references

- [Expo runtime versions](https://docs.expo.dev/eas-update/runtime-versions/)
- [Expo SDK 55+ update environment requirement](https://docs.expo.dev/eas/environment-variables/usage/)
- [Expo staged deployment and artifact promotion](https://docs.expo.dev/eas-update/deployment/)
- [Expo CLI update/republish/rollout reference](https://docs.expo.dev/eas/cli/)
- [Expo update error recovery](https://docs.expo.dev/eas-update/error-recovery/)
- [Expo programmatic access tokens](https://docs.expo.dev/accounts/programmatic-access/)
- [GitHub protected environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment)
