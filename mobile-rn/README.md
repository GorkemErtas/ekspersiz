# EksperSiz React Native migration

This is an **incomplete development migration**, alongside the unchanged Flutter application in `../mobile`. Authentication and the shared visual/security foundation are implemented. The authenticated account route is an integration surface, **not** a replacement for Flutter's dashboard/profile. See the [feature matrix](../docs/migration/FLUTTER_TO_REACT_NATIVE.md) before evaluating readiness.

## Local development

Use Node 24 LTS (at least 24.3), JDK 17 or 21, Android SDK 37/build tools 37, CMake 3.31.6 and an Android API 24+ emulator/device. SDK 58 uses React Native 0.88.1/React 19.3.0; the lockfile records exact resolved versions. The system Node 22.12 is too old for this SDK.

```powershell
cd mobile-rn
npm ci
Copy-Item .env.example .env.local
# Set EXPO_PUBLIC_API_BASE_URL to a local/test backend, including /api/v1.
npx expo prebuild --platform android --no-install
# On Windows, install CMake 3.31.6 via Android Studio's SDK Tools first.
npm run android
```

Use an Expo **development build**, not Expo Go. Android uses `com.gorkem.ekspersiz.dev`, so it can coexist with Flutter. Production configuration is deliberately blocked pending feature/security/visual parity and signing review. No EAS project or remote build is required for local development.

`10.0.2.2` reaches the host from an Android emulator. On a physical device use a reachable test server. Public Expo environment values are embedded in the bundle; never place private credentials in them. Current cleartext network permission is limited to this development application configuration.

Google login needs an existing **development** OAuth web client ID and Android package/certificate registration. For iOS also provide `EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID` and `GOOGLE_IOS_URL_SCHEME` and rebuild on macOS. Do not reuse production Firebase files for the development suffix. Missing configuration produces a real error; no substitute login is implemented.

## Checks

```powershell
npm run typecheck
npm run lint
npm test
npm run format:check
npx expo install --check
npx expo-doctor
npx expo export --platform android
npm run audit:flutter
```

Unit tests mock native animation and SecureStore. They do not validate native animation, secure persistence, Google login, payments, or push delivery. No test calls paid AI or production endpoints.

## Reference captures

Run from Flutter's directory; the source capture test lives in this migration:

```powershell
cd ../mobile
flutter test --no-pub ../mobile-rn/visual/flutter_reference_test.dart --reporter expanded
```

This produces 40 offline captures in `mobile-rn/visual-artifacts/flutter/`, using the actual Flutter screens and original Inter/Material font assets. It leaves Flutter sources unchanged and requires Flutter's existing `pub get` output. `node scripts/save-references.mjs` saves the eight phone references and verifies font hashes against Flutter.

For native comparisons use the same logical viewport, DPR, theme, font scaling, content, keyboard/focus state, and safe-area insets. Native screenshots must be captured in a development build. See [the visual protocol](../docs/migration/VISUAL_PARITY.md). Do not resize images to make the comparison pass.

```powershell
npm run visual:compare -- visual-artifacts/flutter/login-dark-phone.png visual-artifacts/native/login-dark-phone.png visual-artifacts/diff/login-dark-phone.png
```

The command exits nonzero if dimensions differ or >1% of pixels differ at a 0.1 color threshold, with anti-alias differences excluded. A numeric pass still requires review. No RN comparison is considered passed merely because Flutter captures or Jest passed.
