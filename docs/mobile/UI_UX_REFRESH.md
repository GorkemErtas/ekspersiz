# Mobile UI/UX refresh — 5 November 2026

Branch: `feat/mobile-ui-ux-modernization`, based on the latest `origin/master` at `a950cd5`.

## Root cause and assistant fix

`MainShell` placed `assistant-dock` after the flexing screen container, in normal layout. The full-width dock reserved a separate 72+ dp band outside the dashboard ScrollView. Its transparent background exposed the nearly black studio background, so the vehicle card stopped abruptly above a dark horizontal strip. The 56 dp minimum button, vertical padding, and large purple shadow added visual weight. The navigation stacks themselves already used transparent backgrounds; the dock's layout reservation was the problem.

The dock is removed. `FloatingAssistant` is an absolute, transparent overlay inside the content viewport, above the navigation's own layout region. Its wrapper uses `pointerEvents="box-none"`, so only the pill receives touches. The sparkle icon, “AI Asistan” label, accessible action name, home-only visibility, and `/assistant` navigation remain intact.

The pill measures 50 dp at the default font size, with 16 dp horizontal padding, a purple container surface, and a restrained shadow. Its measured height, plus the 12 dp bottom offset and 12 dp clearance, determines the dashboard's scroll padding. This clearance grows with text scaling. Content can scroll behind the transparent area and completely clear the control at the end; there is no fixed full-width footer. MainShell continues to own system SafeArea insets once, and navigation keeps its natural measured height.

At large text sizes on compact phones, the four navigation actions use two columns. Labels retain full font scaling, and the assistant remains anchored above the actual navigation height. Landscape and tablet navigation continue to use the existing side rail. Visited tab state and Android back behavior are preserved.

## Visual changes

- Refined the existing design system: 4-point spacing steps, whole-number typography line heights, 52 dp buttons/inputs, 48 dp icon touch targets, icon and border tokens, clearer placeholder contrast in both themes, and smaller neutral shadows.
- Synchronized restored theme preferences and theme changes with native appearance and the root surface, so native controls receive the selected theme.
- Standardized buttons, focus outlines, fields, selectors, cards, badges, loading/error/empty states, and sheet headers. Regular cards use 16 dp corners, the hero uses 24 dp corners, tracking uses a colored status edge, and the assistant uses a pill shape.
- Improved the dashboard header, responsive action grouping, and workspace selector. Long account names wrap, account switching exposes its current value, and the selector has a 48 dp minimum touch target.
- Reduced the damage-analysis hero's height and aligned its icon, title, description, and CTA on a darker purple gradient with readable text.
- Reworked the primary vehicle card into vehicle identity and a separate metadata row. Tracking now distinguishes `ATTENTION`, `DUE_SOON`, `GOOD`, and unknown states, keeps the status visible alongside reminders, and indicates additional reminders.
- Aligned vehicle, analysis, and notification lists with shared `layoutStyles.listContent`. Added consistent press feedback, improved long-text wrapping, and made unknown analysis severity visually neutral.
- Refined profile rows and destructive-action presentation while retaining the existing confirmation and account-deletion logic.
- Put assistant context/credit controls in the scrollable conversation header. Standardized the composer and message surfaces, disabled empty submissions, and respected reduced motion when scrolling replies. Sending, retry/request IDs, cancellation, credits, speech recognition, and billing behavior remain unchanged.

Directly updated screens: home, workspace selection, navigation, vehicles, analysis history, notifications, profile, and AI assistant. Shared component changes also apply to authentication, vehicle/tracking forms, analysis creation/upload/results, billing, Business, and their selectors/dialogs without changing workflows.

No dependencies, API clients/contracts, backend files, production environment files, app identity, signing/version configuration, authentication, purchase logic, or release pipelines were changed.

## Validation

| Check                                                    | Result                                                                                                                                                                                                          |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| TypeScript                                               | Passed                                                                                                                                                                                                          |
| ESLint                                                   | Passed, zero warnings                                                                                                                                                                                           |
| Jest                                                     | 23 suites / 137 tests passed                                                                                                                                                                                    |
| Existing release/config/fixture script tests             | 20 tests passed; subprocess-dependent tests rerun outside the restrictive sandbox                                                                                                                               |
| Expo configuration validation                            | Passed: development identity/permissions, production guards, and secret-key rejection                                                                                                                           |
| Formatting of all changed mobile source and smoke script | Passed                                                                                                                                                                                                          |
| Full repository mobile formatting                        | Existing failures in four unchanged files: `app.config.ts`, `config/otaUpdate.cjs`, `config/otaUpdate.d.cts`, `scripts/ota-config.test.mjs`                                                                     |
| Expo dependency check / Expo Doctor                      | Existing package-version mismatches; Doctor passed 19/20 checks. Twelve installed packages differ from current SDK recommendations, including SafeArea 5.10.1 versus ~5.11.1. Dependencies were left unchanged. |
| Native Android layout matrix                             | Passed: six configurations, keyboard bounds, and major-screen navigation; 26 verified captures. Final results and selected screenshots are linked below.                                                        |

Regression coverage includes assistant navigation and home-only visibility, tab state retention, transparent touch handling, measured clearance after text scaling, large-text navigation, real tracking-state labels, reminder visibility, dashboard callbacks, empty assistant submissions, successful replies, and billing redirection without an AI request when credits are unavailable.

### Android evidence

Visual checks use API 36 on a dedicated x86_64 emulator with synthetic loopback fixtures. The current JavaScript bundle was embedded in the existing development native shell and signed with the local debug key. This is a JavaScript preview on an existing native shell, not a fresh native build or production artifact.

The matrix covers 320×640, 390×844, 430×932, and 844×390 viewports; light/dark themes; 1×, 1.6×, and 2× text; gesture/three-button navigation; assistant hit targets and route opening; touch passthrough; final-card scroll clearance; keyboard bounds; and other major screens. The smoke script records the installed preview APK hash and restores prior emulator display/font/navigation settings.

- [Machine-readable final results](ui-refresh/results.json)
- [Home, dark theme](ui-refresh/phone-dark.png)
- [Compact phone, light theme, 1.6× text, final card](ui-refresh/small-light-large-text-scroll-end.png)
- [Assistant with keyboard](ui-refresh/assistant-keyboard.png)

All captures and accessibility XML dumps remain locally under `mobile-rn/visual-artifacts/ui-refresh/captures`. The local preview APK is `mobile-rn/visual-artifacts/ui-refresh/preview.apk`; binaries are not committed.

To repeat against a fixture-only `.dev` preview with the same source:

```powershell
cd mobile-rn
# In a separate terminal:
node visual/fixture-server.mjs
# In the test terminal, explicitly choose the dedicated emulator:
$env:ANDROID_SERIAL = 'emulator-5554'
node visual/assistant-layout-smoke.mjs
```

The app must be explicitly configured to use `http://127.0.0.1:18080/api/v1` in the test preview, with dotenv disabled during bundling. The fixture server is not imported by the application. No real AI requests or store purchases are made by the layout smoke test.

## Remaining limits

iOS native rendering, VoiceOver/TalkBack use, physical devices, and real authentication/AI/billing/push integrations were not validated in this Windows emulator run. Existing business-logic regression tests passed, but synthetic fixtures are not evidence of live service behavior. No original screenshot attachment was available; the source diagnosis was checked against newly captured Android screens. There was no production build, OTA publication, Google Play release, or merge into `master`.

The existing native shell retains Android's light contrast scrim in the three-button system navigation area even with the app's dark theme. This is outside the app navigation, and its inset is respected in every tested layout. Changing that native system-bar policy was not included in the source-only UI refresh.

## Implementation commits

- `0db8e40` — `refactor(ui): refine shared mobile design tokens and controls`
- `8bd1f3c` — `fix(ui): restore dashboard space with compact floating assistant`
- `cbf042e` — `style(ui): refine dashboard hierarchy and tracking states`
- `1a16040` — `style(ui): align lists forms sheets and assistant presentation`
- `2f4b906` — `fix(ui): keep navigation labels readable at large text sizes`
- `7096797` — `fix(ui): synchronize native surfaces with saved theme`

The final evidence commit adds the native smoke script, selected captures, and this report.
