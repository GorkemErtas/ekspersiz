import type { ExpoConfig } from 'expo/config';

const production = process.env.APP_VARIANT === 'production';
for (const [name, value, prefix] of [
  [
    'EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY',
    process.env.EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY,
    'goog_',
  ],
  [
    'EXPO_PUBLIC_REVENUECAT_IOS_PUBLIC_KEY',
    process.env.EXPO_PUBLIC_REVENUECAT_IOS_PUBLIC_KEY,
    'appl_',
  ],
] as const) {
  if (value && !value.startsWith(prefix) && !value.startsWith('test_'))
    throw new Error(
      `${name} must be a platform public RevenueCat SDK key. Never bundle a secret API key.`,
    );
}
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
    versionCode: Number(process.env.ANDROID_VERSION_CODE ?? 52),
    blockedPermissions: [
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
    ],
    ...(process.env.GOOGLE_SERVICES_FILE
      ? { googleServicesFile: process.env.GOOGLE_SERVICES_FILE }
      : {}),
    adaptiveIcon: {
      foregroundImage: './assets/images/ekspersiz_logo.png',
      backgroundColor: '#08070B',
    },
  },
  ios: {
    buildNumber: process.env.IOS_BUILD_NUMBER ?? '52',
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
    'expo-image',
    'expo-sharing',
    'expo-asset',
    '@react-native-community/datetimepicker',
    [
      'expo-image-picker',
      {
        photosPermission:
          'Hasar analizi için seçtiğiniz fotoğraflara erişim gerekir.',
        cameraPermission: 'Hasar fotoğrafı çekmek için kamera erişimi gerekir.',
        microphonePermission: false,
      },
    ],
    [
      'expo-location',
      {
        locationWhenInUsePermission:
          'Yakındaki servisleri göstermek ve analiz konumunu belirlemek için konum izni gerekir.',
      },
    ],
    [
      'expo-speech-recognition',
      {
        microphonePermission:
          'AI Asistan’a sesli soru yazmak için mikrofon izni gerekir.',
        speechRecognitionPermission:
          'Söylediklerinizi yazıya çevirmek için konuşma tanıma izni gerekir.',
      },
    ],
    ['./plugins/withFirebase.cjs'],
    ...(process.env.EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY ||
    process.env.EXPO_PUBLIC_GOOGLE_MAPS_IOS_API_KEY
      ? [
          [
            'react-native-maps',
            {
              androidGoogleMapsApiKey:
                process.env.EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY,
              iosGoogleMapsApiKey:
                process.env.EXPO_PUBLIC_GOOGLE_MAPS_IOS_API_KEY,
            },
          ] as [string, Record<string, string | undefined>],
        ]
      : []),
    ['expo-splash-screen', { backgroundColor: '#08070B' }],
    [
      'expo-build-properties',
      {
        android: { usesCleartextTraffic: true, cmakeVersion: '3.31.6' },
        ...(process.env.GOOGLE_SERVICES_PLIST
          ? { ios: { useFrameworks: 'static' } }
          : {}),
      },
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
  extra: {
    androidFirebase: !!process.env.GOOGLE_SERVICES_FILE,
    iosFirebase: !!process.env.GOOGLE_SERVICES_PLIST,
    androidMaps: !!process.env.EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY,
    iosMaps: !!process.env.EXPO_PUBLIC_GOOGLE_MAPS_IOS_API_KEY,
  },
};
export default config;
