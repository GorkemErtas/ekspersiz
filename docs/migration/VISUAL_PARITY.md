# Flutter visual reference and review gate

The current `mobile/lib/` source is the reference implementation. A screen is not visually accepted until a reviewer has compared a React Native development build with an equivalent Flutter capture. Existing `docs/screenshots/` images can provide historical context; the older UI previews use Roboto and must not be treated as an Inter typography baseline.

## Inspected foundation

| Property | Flutter reference | RN location / status |
| --- | --- | --- |
| Dark canvas / surface / input | `#08070B` / `#111014` / `#0E0D11` | `src/design/tokens.ts` |
| Light canvas / surface / input | `#F8F6FB` / `#FFFFFF` / `#FCFAFD` | Tokens |
| Brand primary / deep / secondary | `#8B5CF6` / `#6D28D9` / `#C084FC` | Tokens; light primary uses deep violet |
| Main / muted text | dark `#F7F4FB` / `#B9B1C5`; light `#211A29` / `#655C6F` | Tokens |
| Spacing | 4, 8, 15, 22, 30, 36; page inset 18 | Tokens, logical px |
| Corners | 12, 16, 24, 28; pill 999 | Tokens |
| Minimum touch / button | 48 / 50, content may grow with text | Shared components; no text scaling cap |
| Typography | Inter; headline 22, title 20, body 14/21, input 16/24 | Byte-identical original Regular/Medium assets; preserve GoogleFonts family selection and synthetic weight changes; no network font fetching |
| Icons | Flutter MaterialIcons rounded/outlined codepoints | Same OTF asset and codepoints, Apache license included |
| Brand gradient | `#6D28D9` → `#8B5CF6` → `#C084FC`, top-left to bottom-right | Centralized tokens |
| Soft / elevated / brand shadows | Dual dark shadows, theme-specific light shadows | Centralized RN `boxShadow`; native rendering review pending |
| Studio surface | Two radial lights, stops 0/.42/1, peripheral cubic paths, luminance-dependent opacity | `StudioBackground.tsx`, direct painter translation; SVG overlay ignores touches and accessibility |
| Responsive background | span ≤600, depth ≤1000, viewport anchored | SVG behind Router; keyboard position must be checked on device |
| Motion | 140/240/320 ms; theme 420; easeOutCubic; press .985; route delta (.025,.018) | Timing tokens and Reanimated auth fade; exact slide/route/theme animation parity remains pending |
| Adaptive columns | width ≥760 and text scale ≤1.3 | Recorded for future dashboard/detail port; not yet implemented |
| Navigation | four tabs; surface bar 72, margin 12/10, radius 24; wide rail | Recorded; full MainShell port pending |

## Screens inspected before implementation

Read `app_theme.dart`, `app_background.dart`, `app_motion.dart`, `auth_shell.dart`, `primary_button.dart`, and each corresponding Flutter screen before changing RN presentation.

| Screen | Source measurements and behavior | RN route | Visual status |
| --- | --- | --- | --- |
| Login | Max content 460; viewport inset 18/26; 88px logo radius28; title gap16, description gap6, brand-to-card26; card padding22 (17 below360), radius28; card top spacer10, heading22/900; subtitle gap8, fields gap26; 56px inputs separated15; forgot action right aligned; filled primary with dark foreground; divider gap22; outlined Google/register gap12 | `/login` | Widget references and native dark comparison captured; **acceptance failed**, see below |
| Register | Same shell, max520; name/email/password/confirm; field gaps15; password guidance surface, 14px padding; CTA `Hesap Oluştur`; divider18; outlined `Zaten Hesabım Var` | `/register` | Flutter references captured; RN native comparison pending |
| Forgot password | Max460; 54px gradient icon radius18 plus14px title gap; body gap22; code-request state becomes six-digit/new-password/confirm state; submit22; return15; email can be changed without losing route | `/forgot-password` | Both states implemented; initial-state references captured; reset-state capture pending |
| Email verification | Max520; 54px gradient icon; 30px heading gap, 26px field gap; 6-digit centered field, 22px/800, letter spacing8; autofocus; 5-minute guidance; verify and resend mutually exclusive | `/verify-email?email=...` | Flutter references captured; RN native comparison pending |
| Password change | AppBar60, max640, page inset18/top15/bottom110; AppCard18/radius24; current/new/confirm fields; guidance14; button22 | `/change-password` | Functional initial port; capture, icon/panel and navigation matching pending |
| Account integration surface | Reuses profile avatar66/radius24 and basic identity fields | `/account` | Development integration only; **not** a migrated Profile/MainShell |

## Capture matrix

`mobile-rn/visual/flutter_reference_test.dart` captures the four public auth screens in each combination below (40 captures total). It renders actual Flutter widgets with Inter fonts supplied offline; no Flutter application source or theme is replaced. These are widget captures, without OS chrome or keyboard pixels.

| Name | Logical viewport | Text scale | DPR | Themes |
| --- | --- | --- | --- | --- |
| compact | 320 × 640 | 2.0 | 1 | dark/light |
| phone | 390 × 844 | 1.0 | 1 | dark/light |
| large | 430 × 932 | 1.5 | 1 | dark/light |
| landscape | 844 × 390 | 1.5 | 1 | dark/light |
| tablet | 1024 × 768 | 1.0 | 1 | dark/light |

Phone references are saved in `reference/`; all 40 are reproducible under ignored `mobile-rn/visual-artifacts/flutter/`. For a scrolled form, capture the same scroll offset and the same focused field. Add matching keyboard-open, error, loading, disabled, success, empty and offline captures as each corresponding state is ported. These are outstanding gates, not implied by the initial-state captures.

## Native comparison procedure

1. Run a development build with a test backend. Open the same screen, theme and fixture data in Flutter and RN. For public auth screens, no backend is needed to inspect initial layout.
2. Prefer native-to-native captures on the same emulator/device for system chrome, safe area and font rendering. Record OS, resolution, density, font scale, keyboard and reduced-motion settings in an artifact manifest. Flutter widget captures have zero safe-area insets; compare them only with native captures configured identically, or capture equivalent Flutter native screenshots first.
3. Use `adb shell wm size` / `wm density` to inspect configuration. If overriding them, record and restore the original values afterward. A 390×844 image at DPR1 is not equivalent to a 1080×2340 image scaled afterward.
4. Capture Android PNGs with `adb shell screencap -p /sdcard/ekspersiz-reference.png`, then `adb pull` into `visual-artifacts/native/`. Avoid PowerShell text redirection for binary PNG data. Remove the temporary device screenshot after pulling.
5. Run `npm run visual:compare -- <flutter.png> <rn.png> <diff.png>`. The tool refuses differing dimensions and never resizes/crops/translates a screenshot. It outputs a diff and JSON, and exits nonzero above the default mismatch limit (1%). Never compare a Flutter reference against itself as proof of RN parity.
6. Review background, border, glyph, baseline, wrapping, card and input bounds, shadows and alignment. Address meaningful differences in tokens/shared primitives first. Do not relax limits or replace reference images with RN renders to hide differences.
7. Separately check TalkBack/VoiceOver, large text, 48px touch areas, keyboard reachability, focus order, reduced motion, navigation back/gesture behavior and animation frame pacing. Static pixel comparisons cannot establish these.

## Acceptance tracking

Native dark login was captured from both real applications on the same Android API36 emulator at 390×844, density160 (DPR1), text scale1.0, keyboard closed. `flutter_native_reference.dart` renders the actual Flutter LoginScreen with the actual theme/background/font assets and skips Firebase/session/API bootstrap. The RN image comes from the compiled Expo development application. Development overlays were dismissed. Captures retain OS chrome; clock/status-icon differences contribute slightly to the diff.

| Flutter native reference | React Native development build | Pixel diff |
| --- | --- | --- |
| ![Flutter](native/flutter-login-dark.png) | ![React Native](native/react-native-login-dark.png) | ![Diff](native/login-dark-diff.png) |

The final [comparison report](native/login-dark-diff.json) records **15,799 differing pixels (4.80%)**, above the 1% limit. This is a failed gate. Corrections made from native comparison include fractional Flutter line heights, input border sizing and text insets, outlined button dimensions, text-button sizing, valid SVG gradient stops, original font bytes and Android button text synthesis that clipped trailing words. The logo decode uses Flutter's 256px cache target. Remaining baseline/rasterization, surface and shadow differences must be resolved; other screens, themes, states and sizes require native comparisons. No migrated screen is signed off.

To reproduce native Flutter capture, run from `mobile/` on a dedicated test emulator:

```powershell
flutter build apk --debug --no-pub --target ../mobile-rn/visual/flutter_native_reference.dart --target-platform android-x64
# Optional: --dart-define=REFERENCE_SCREEN=register --dart-define=REFERENCE_THEME=light
```

This produces a reference debug APK under Flutter's ignored build output, using its existing application ID. Install it only on the dedicated test emulator; rebuild the default entrypoint for normal Flutter development. Never install a reference build over a user's production device. Native validation here did not exercise real account, email, purchase, AI or notification services.

Production release remains blocked until the remaining functional/native work and visual matrix are complete. Screenshots and code-derived tokens alone do not establish acceptance.
