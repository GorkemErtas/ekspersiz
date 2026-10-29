import type { ExpoConfig } from 'expo/config';

const production = process.env.APP_VARIANT === 'production';
// Release configuration remains a deliberate future step after parity review.
if (production)
  throw new Error(
    'Production builds require the completed migration and Play signing/version review. See docs/migration/FLUTTER_TO_REACT_NATIVE.md.',
  );

const config: ExpoConfig = {
  name: 'EksperSiz Dev',
  slug: 'ekspersiz-mobile',
  version: '1.0.0',
  scheme: 'ekspersiz-dev',
  orientation: 'default',
  userInterfaceStyle: 'automatic',
  icon: './assets/images/ekspersiz_logo.png',
  android: {
    package: 'com.gorkem.ekspersiz.dev',
    versionCode: 1,
    ...(process.env.GOOGLE_SERVICES_FILE
      ? { googleServicesFile: process.env.GOOGLE_SERVICES_FILE }
      : {}),
    adaptiveIcon: {
      foregroundImage: './assets/images/ekspersiz_logo.png',
      backgroundColor: '#08070B',
    },
  },
  ios: {
    bundleIdentifier: 'com.gorkem.ekspersiz.dev',
    supportsTablet: true,
    ...(process.env.GOOGLE_SERVICES_PLIST
      ? { googleServicesFile: process.env.GOOGLE_SERVICES_PLIST }
      : {}),
    infoPlist: {
      CFBundleLocalizations: ['tr'],
      ITSAppUsesNonExemptEncryption: false,
    },
  },
  plugins: [
    'expo-router',
    'expo-secure-store',
    'expo-font',
    ['expo-splash-screen', { backgroundColor: '#08070B' }],
    [
      'expo-build-properties',
      { android: { usesCleartextTraffic: true, cmakeVersion: '3.31.6' } },
    ],
    ...(process.env.GOOGLE_IOS_URL_SCHEME
      ? [
          [
            '@react-native-google-signin/google-signin',
            { iosUrlScheme: process.env.GOOGLE_IOS_URL_SCHEME },
          ] as [string, Record<string, string>],
        ]
      : []),
  ],
  experiments: { typedRoutes: true },
};
export default config;
