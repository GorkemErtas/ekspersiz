# Flutter → React Native / Expo migration

Assessment date: 29 October 2026. Branch: `migration/flutter-to-expo`.

**Status: incomplete, development only.** The Flutter app is intact and remains the production implementation. `mobile-rn/` contains a real authentication implementation and shared design/session/HTTP foundation. It does not yet replace the 26-screen Flutter app. Production builds are blocked in the RN app configuration. Nothing was pushed, merged, deployed, purchased or released.

## Source assessment

`flutter-inventory.json` inventories 26 screen files, 28 domain model files, 18 feature service files, 56 test/support/fixture files, backend controllers and 58 backend DTO files. Each source record includes a SHA-256 hash. Regenerate with `npm run audit:flutter` after Flutter changes; the file is an index, not a substitute for reading each implementation.

Inspected sources include Flutter dependencies/theme/widgets/auth, workspace/session/HTTP, vehicle/tracking contracts, inspection upload/analysis, billing and RevenueCat, FCM lifecycle, custom integrity/onboarding integrations, Android version/signing/permissions, iOS permissions, backend endpoint mappings, existing UI/testing architecture, and workspace/billing documentation. No secrets, signing configuration values, service account files or production data were copied.

UI measurements and the per-screen capture gate are in [VISUAL_PARITY.md](VISUAL_PARITY.md). Flutter is the reference implementation; this migration does not authorize a redesign.

## Implementation architecture

| Concern | Implementation |
| --- | --- |
| Native application | Expo SDK 58.0.21; React Native 0.88.1; React 19.3.0; CNG development builds |
| Navigation | Expo Router; public auth routes separated from authenticated routes by protected stacks |
| Design | `src/design/tokens.ts`, native Text/Input/Pressable/ScrollView, SVG studio painter, exact Flutter Material icon font, offline Inter |
| Sensitive storage | Expo SecureStore, serialized credential writes; Flutter encrypted preferences are not imported |
| Session | External store with synchronous authority generations, abort controllers and latest-profile guards; React `useSyncExternalStore` |
| Server cache | TanStack Query; keys include user/workspace/business/generation; cancellation and clearing at authority changes; no persisted protected cache |
| HTTP | Fetch; JSON/multipart support; workspace echo validation; 30s default timeout; no automatic retries |
| Shared client state | Session/theme providers only; Zustand not needed for this increment |
| Tests | Jest/Expo preset and React Native Testing Library; native animation/storage mocked only in tests |

Expo's [SDK 58 announcement](https://expo.dev/changelog/sdk-58) and [SDK compatibility reference](https://docs.expo.dev/versions/latest/) were checked before choosing versions. Versions of native SDK packages were selected with Expo install, then checked against its compatibility table. The installed system Node 22.12 is below the minimum; verification uses an isolated Node 24 runtime. Dependencies/lockfile live exclusively in `mobile-rn/`.

## Functional equivalence checklist

`Implemented` means code and local tests/bundle validation where noted; it does not imply external service or native visual acceptance. Pending features remain available in Flutter and must be ported before replacement. No fake successful production responses are used.

| Flutter screen / feature | RN mapping / status | Remaining acceptance work |
| --- | --- | --- |
| Splash | Startup SecureStore restore + `/auth/me`; **partial** | Port existing splash UI, mandatory version/update policy and onboarding routing |
| Login | `/login`, email/password + native Google boundary; **implemented** | Device Google login, welcome-credit integrity path; native comparison captured but acceptance threshold not met |
| Register | `/register`; **implemented** | External email delivery and native screenshots |
| Email verification | `/verify-email`; **implemented** | Expiry/resend server checks, autofocus/keyboard capture |
| Forgot/reset password | `/forgot-password`, both phases; **implemented** | Server delivery/expiry, success-state and keyboard capture |
| Change password | `/change-password`, replacement bearer header, safe re-login on older server; **implemented** | Complete panel/icon/toolbar matching and native screenshots |
| Onboarding | **pending** | All guide artwork/transitions, installation-only no-backup atomic marker, first-launch behavior |
| MainShell | **pending** | Four tabs, wide rail, workspace shell reset, app lifecycle refresh and notification badge |
| Home | **pending** | Dashboard/credit overview, adaptive columns and all entry points |
| Vehicle list | **pending** | CRUD, primary vehicle, search/empty/menu, owner/member server access |
| Vehicle details | **pending** | Overview, history, mileage, inspection and tracking links |
| Add/edit vehicle | **pending** | Catalog, plate normalization, current tracking initialization/validation |
| Maintenance form | **pending** | Existing create/edit/delete DTOs and date/mileage handling |
| Reminder form | **pending** | Reminder types, recurrence, completion and notification behavior |
| Create inspection | **pending** | Vehicle/city/location contract and availability/quota errors |
| Upload damage image | **pending** | Two-photo workflow, permissions, EXIF orientation/limits/cleanup and scoped previews |
| Analyzing | **pending** | Exactly one explicit analysis invocation, progress/cancel/lifecycle and error mapping |
| Inspection history | **pending** | Workspace-isolated reports and images, empty/error/offline states |
| Inspection result | **pending** | Structured findings, severity, repair/cost, HITL/additional-photo states and report regeneration |
| Damage assessment record | **pending** | Draft/update/finalize contracts, legal copy, PDF images/fields |
| Nearby services | **pending** | Same Google Maps styling/location, result panel, navigation links |
| AI assistant | **pending** | Quota/credits, authenticated requests, Markdown, vehicle context, Turkish speech and cancellation |
| Profile | `/account` is an **integration surface only** | Port complete profile UI/actions and MainShell; existing plan/company flows not present |
| Subscription | **pending** | Complete RevenueCat integration and purchase/restore/reconciliation semantics |
| Business management | **pending** | Create/invite/accept/member management and owner/member restrictions |
| Notification center | **pending** | List/unread/read-all plus native FCM lifecycle |
| Account deletion/logout | Real endpoints/local clearing on `/account`; **implemented boundary** | Device token unregister once FCM port exists; real destructive operations not executed |
| Light/dark theme | Exact palette tokens, local preference; **partial** | 420ms theme transition parity and full screen coverage |
| PDF export/share | **pending** | Inspection and assessment A4 layouts, Turkish fonts, images, pagination and cleanup; compare documents with Flutter |
| Android Play update | **pending** | Backend minimumAndroidBuild + immediate update/store fallback; OTA is not equivalent |
| Welcome credits | **pending** | Custom Play Integrity module, server challenge/hash/claim and device identity; never fabricate proof |

## API and security contracts

Keep the existing Spring Boot `/api/v1` contract and FastAPI backend unchanged. No backend edits are part of this increment.

| Area | Existing contract / migration obligation |
| --- | --- |
| Authentication | `/auth/login`, `/google`, `/register`, `/verify-email`, `/resend-verification`, `/forgot-password`, `/reset-password`, `/change-password`, `/me`, `/account`; JSON field names follow Flutter/backend |
| Token rotation | Password-change success may return `Authorization: Bearer ...`; persist before further requests. No refresh-token endpoint exists in the audited client; do not invent silent renewal |
| Workspace | Authenticated requests send `X-Workspace: PERSONAL|BUSINESS`. Nonidentity successes must echo exactly the selected workspace. `/workspace` must confirm userId/type/businessId before publishing a switch |
| Availability | Membership alone and `subscriptionPlan == BUSINESS` do not grant access. Require `workspaceAvailable == true` **and** `workspaceAccessStatus == ACTIVE`; server remains authoritative |
| Expiry | `403` with `validationErrors.code == WORKSPACE_UNAVAILABLE` revokes Business selection/availability, retains membership and personal session. Do not delete membership or personal data |
| Roles | OWNER/MEMBER are parsed explicitly. Server authorizes all operations. A member must never gain owner purchase authority from a plan label |
| Races | Logout/login/workspace/membership changes advance generation, abort old requests, clear cache and prevent stale 401/profile/authorization responses affecting the new identity. Plan-only metadata refresh keeps generation |
| Credentials | Serialized writes prevent old login/rotation writes finishing after logout/new login. App-specific SecureStore keys; no AsyncStorage/plaintext JWT |
| Protected media | Future image implementation must use authenticated byte access and authorization-before-reuse, with user/workspace/generation scoped keys and bounded memory; do not use public image URLs or persistent cross-user image caches |
| Vehicles | `/vehicles`, `/{id}`, `/{id}/primary`, `/{vehicleId}/overview`, `/maintenance`, `/reminders`, `/history`; retain existing DTOs/server validation |
| Inspection creation | POST `/inspections?vehicleId=...&city=...&latitude=...&longitude=...`, not a new JSON schema |
| Photos | **Two current required photos**: damage and vehicle context. POST multipart `image` to `/{id}/image` and `/{id}/context-image`; preserve this even though older docs describe one photo |
| Analysis | POST `/{id}/analyze?requireContext=true[&vehicleRegion=FRONT|REAR]`; explicit 120s timeout; image upload90s. Do not auto-retry paid operations |
| Image optimizer | Source ≤40MiB, bounded dimensions/pixels, bake EXIF orientations 1–8, reject animation, upload JPEG ≤10MiB; mirror optimizer's current settings before porting |
| Assistant | `/ai-assistant/entitlement` and `/chat`; requestId reused for same pending payload, last six messages, each content ≤2000 UTF-16 units without split surrogate pairs, optional vehicleId, 75s timeout |
| Native push | `/notifications/devices` receives native **FCM** token and `platform: IOS|ANDROID`; unregister via DELETE with encoded `token`; token refresh + foreground/opened events |
| iOS push | Expo Notifications returns APNs for native iOS device token, not FCM. Select RN Firebase Messaging (with compatible native setup) for cross-platform FCM, or prove another FCM bridge; do not pass an APNs/Expo token to this backend |

## Billing integrity (not ported yet)

Read `billing_service.dart`, `revenue_cat_gateway.dart`, the 3 billing model groups and their race tests before implementing. Use the backend's `billingCustomerId` verbatim; never derive it from email or invent a new namespace. Configure the single native RevenueCat identity through a serialized queue. Preserve exact existing public keys via environment configuration; do not change dashboards.

Preserve `credits_v1` offering with current-offering fallback; package aliases and real store SKUs are indexed separately, with the real SKU winning a collision. Before consumables, POST `/credits/purchase-intents/{productId}`. After the native transaction, sync once via `/billing/sync`, then query `/credits/purchases/{encodedTransactionId}`. Only `confirmed == true` establishes success. Native SDK entitlements/receipts alone never grant server credits or Business access.

Business subscription purchases must reconcile existing backend/store state to suppress duplicates, preserve proration/deferred plan replacement, and remain OWNER-only under current backend policy. Preserve personal/business wallet isolation, sandbox rejection, cancelled-but-active periods, grace/billing problems, expired/unavailable status, refunds, webhook idempotency and delayed webhook pending state. Store accepted + failed reconciliation is pending, not a failed payment that triggers another purchase. No polling/sync loops.

Required tests before enabling purchases: cancellation, pending/declined/restore, repeated transactions/webhooks, owner/member, expiry/renewal, logout or workspace change while a native sheet is open, delayed sync, sandbox/production identity and reopening a company setup already paid. Store tests must use approved manual sandbox cases in existing `docs/billing/`; none were run here. RevenueCat's [native installation guide](https://www.revenuecat.com/docs/getting-started/installation/reactnative) also requires checking Android launchMode; Flutter currently uses `singleTop`, whereas an Expo template may use `singleTask`. Fix through a config plugin when integrating billing, and verify external payment-app return.

## Dependency migration / compatibility

Installed versions are in `mobile-rn/package-lock.json`. Pending candidates must undergo native compilation and license/platform review before adding them. They are not claimed as integrated.

| Flutter dependency / integration | RN replacement / status | License / risk |
| --- | --- | --- |
| flutter/material + google_fonts | Native RN StyleSheet + bundled Inter + original Material Icons; installed | RN MIT; Inter OFL; Material Icons Apache-2.0 (included) |
| http / http_parser | Fetch + FormData; implemented | No added HTTP package; preserve multipart boundary and filename/MIME |
| flutter_secure_storage | expo-secure-store SDK-compatible; installed | MIT; storage format is not compatible with Flutter |
| Navigation | expo-router SDK-compatible; installed | MIT; full MainShell port pending |
| App state / API cache | TanStack Query; installed | MIT; abort/clear on protected scope changes |
| flutter animations | Reanimated4.7.1 + Worklets0.13.0; installed | MIT; RN0.88 compatible according to Expo; timing/native parity pending |
| image_picker | expo-image-picker; pending | Candidate MIT; Android photo picker/camera/limited iOS photo access |
| image | expo-image-manipulator + image header validation; pending | Candidate MIT; decoding must remain bounded before allocation; animation/orientation parity |
| geolocator/geocoding | expo-location; pending | Candidate MIT; foreground location/reverse geocode and denial states |
| google_maps_flutter | react-native-maps; pending | Candidate MIT; Google provider, existing style, per-app certificate/key restrictions |
| url_launcher | expo-linking; installed via Router | MIT; safe URL schemes for maps/Markdown |
| purchases_flutter | react-native-purchases; pending | Candidate MIT; identity, native store return, server authority |
| firebase_core/messaging | @react-native-firebase/app + messaging; pending | Candidate Apache-2.0; SDK58/CNG and iOS frameworks/APNs/FCM compatibility must be proven |
| pdf/share_plus/path_provider | expo-print + sharing + file-system; pending | Candidate MIT; embed Turkish fonts, A4/page breaks/images; compare both document types |
| google_sign_in | @react-native-google-signin/google-signin16.2.0; installed | MIT; development build required; native certificate/client IDs still need manual setup |
| package_info_plus | expo-application; pending | Candidate MIT; native versionCode for update policy |
| in_app_update | Local Expo module wrapping Google Play Core, or maintained compatible module after verification; pending | Do not pick an unverified package or substitute OTA; retain immediate update behavior |
| speech_to_text | expo-speech-recognition; pending | Candidate MIT; verify maintained release/RN0.88 native compatibility, Turkish locale availability and cancellation |
| flutter_markdown_plus | Maintained native Markdown renderer after evaluation; pending | Do not substitute a web view; verify safe links, lists/headings/code/selectable text |
| installation MethodChannel | Small Expo native module/no-backup directory; pending | Must not use persistent iOS Keychain for first-install guide completion |
| integrity MethodChannel | Small Expo native Play Integrity module; pending | Preserve backend challenge/requestHash/device-ID behavior; no fake tokens |

Official setup sources: [Expo Router installation](https://docs.expo.dev/router/installation/), [SecureStore](https://docs.expo.dev/versions/latest/sdk/securestore/), [Reanimated](https://docs.expo.dev/versions/latest/sdk/reanimated/), [Google Sign-In Expo setup](https://react-native-google-signin.github.io/docs/setting-up/expo), [native push token API](https://docs.expo.dev/versions/latest/sdk/notifications/). Candidate entries are architectural mappings, not a certification of future package versions.

## Environment and native build

See `mobile-rn/README.md` and `.env.example`. Local development uses no production Firebase/OAuth/billing configuration. The server URL includes `/api/v1`. Expo public variables are not secret. Native Google/Firebase inputs are supplied outside version control, separately per application ID/certificate.

Local Android development compilation:

```powershell
cd mobile-rn
npm ci
npx expo prebuild --platform android --no-install
./android/gradlew.bat -p android app:assembleDebug -PreactNativeArchitectures=x86_64 --console=plain
npm start
```

On macOS, configure development iOS URL scheme and native input files, run `npx expo prebuild --platform ios`, then `npm run ios`. Windows cannot compile or validate iOS. No production keystore is generated or replaced. Generated native directories, local configurations and build outputs are ignored.

## Future Google Play update checklist

- [ ] Finish every pending feature and visual/native quality gate; replace the temporary account surface with faithful MainShell/Profile.
- [ ] Set the eventual production application ID to **`com.gorkem.ekspersiz`**; keep development suffix separate. Do not create a new production store listing.
- [ ] Review minimum OS change: RN/SDK58 requires Android API24+, iOS15.1+. Compare the actual installed Flutter user base before rollout; older Android devices cannot receive this replacement.
- [ ] Query the Play Console manually for the highest published/reserved versionCode. Flutter source is `1.0.0+52`; eventual RN versionCode must exceed the Play maximum, not just 52.
- [ ] Reuse the existing Play App Signing enrollment and upload-key process. Supply upload keystore/passwords through established secure CI/local mechanisms; do not regenerate, copy into git or replace credentials.
- [ ] Register production and development OAuth fingerprints correctly: Play app-signing certificate versus local debug/upload certificate are different. Check Maps restrictions and Firebase app registrations per environment.
- [ ] Verify production Firebase/APNs/FCM registration and logout token deletion. Never send Expo push tokens to Spring Boot.
- [ ] Require a one-time re-login if Flutter storage cannot be read. Do not delete server accounts, vehicles, reports, wallet balances, memberships, purchases or subscriptions. RevenueCat restores/reconciliation must reconnect the same billingCustomerId.
- [ ] Confirm first-install guide marker and theme preference migration behavior explicitly; no assumption that SecureStore shares Flutter's storage/backup format.
- [ ] Disable cleartext traffic for production; review permissions/privacy disclosures, notification/speech/photo/location denial paths and Android native billing/update behaviors.
- [ ] Run signed upgrade testing from an installed Flutter build on internal testing, including existing subscriptions/credit balance, expired companies, logout and account switching.
- [ ] Compare Turkish A4 report PDFs, images and native share cleanup against Flutter outputs.
- [ ] Prepare an AAB using the existing secure release process only after explicit release authorization; review staged rollout/rollback. No upload/submission is automated here.

## Validation results and open gates

Current executed results are recorded as work finishes; no native/external pass is implied by a source audit.

| Check | Result |
| --- | --- |
| Flutter reference capture test | **40 passed**, four public auth screens × five viewports × two themes; actual Inter fonts |
| Strict TypeScript | **Passed** |
| ESLint | **Passed** |
| Prettier | **Passed** |
| Jest | **35 passed**, five suites: HTTP/session/workspace races, auth payloads, native Google boundary/cancellation and login interactions |
| Android Hermes bundle | **Passed**; export generated native Hermes bytecode |
| Android prebuild | **Passed**, generated development project only |
| Expo compatibility / doctor | **Passed**; dependencies up to date; Doctor **18/18** |
| Android native compilation | **Passed**, x86_64 development APK; CMake 3.31.6 resolved Windows Ninja path failure; no dependency downgrade |
| Native startup | Cold launch and login deep link exercised on API36 emulator; Router stays mounted behind storage-loading overlay to prevent a blank stack |
| Native screenshot comparison | **Executed, failed**: dark login, same emulator, 390×844/DPR1/text1.0. Final mismatch **4.80%**, threshold 1%; remaining typography/baseline, surface/shadow differences require review. Other screen/state comparisons pending |
| iOS compilation/device | Not run; requires macOS/Xcode/native environment |
| Backend regression suite | Not run; backend unchanged |
| Native service/store/PDF/paid AI | Not run; no real payment or paid AI invocation |
| Dependency vulnerability audit | **17 findings: 14 low, 3 high**, through transitive `zod`/`deepmerge` and their dependents. No forced major-version override/downgrade was applied; compatible upstream remediation is a production gate |

Native screenshots/diff are saved in [native/](native/); [the visual report](VISUAL_PARITY.md) distinguishes captured references from acceptance. CMake installation and generated APKs are local build artifacts. The offline Flutter reference entrypoint writes Flutter's normal ignored debug APK output; rebuild without `--target` before using that output as the regular Flutter app. Flutter sources remain unchanged.

Major remaining work is implementation, not just unavailable credentials: vehicle/tracking, inspection/assistant, reports, maps, notifications, onboarding/version update, billing/company features and full navigation/profile. The migration must not be presented as feature-complete or ready for a Play update.

The future Business-only web application is outside this migration. Keep domain/API access semantics explicit; eventual OWNER and MEMBER access must be granted by the server's actual workspace availability, never by personal plan labels or frontend routes alone.
