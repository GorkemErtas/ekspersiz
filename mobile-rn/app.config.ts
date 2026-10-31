import type { ExpoConfig } from 'expo/config';
import {
  androidReleaseConfig,
  productionPackage,
} from './config/androidRelease.cjs';

if (
  process.env.APP_VARIANT &&
  !['development', 'production'].includes(process.env.APP_VARIANT)
)
  throw new Error('APP_VARIANT must be development or production.');
const production = process.env.APP_VARIANT === 'production';
const release = production
  ? androidReleaseConfig(process.env, __dirname)
  : undefined;
const optimizedRelease =
  production || process.env.ANDROID_RELEASE_OPTIMIZE === '1';
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
const config: ExpoConfig = {
  name: production ? 'EksperSiz' : 'EksperSiz Dev',
  slug: 'ekspersiz-mobile',
  version: release?.versionName ?? '1.0.0',
  scheme: production ? 'ekspersiz' : 'ekspersiz-dev',
  orientation: 'default',
  userInterfaceStyle: 'automatic',
  icon: './assets/images/ekspersiz_logo.png',
  android: {
    package: production ? productionPackage : 'com.gorkem.ekspersiz.dev',
    allowBackup: !production,
    permissions: [
      'android.permission.RECORD_AUDIO',
      'android.permission.POST_NOTIFICATIONS',
    ],
    versionCode:
      release?.versionCode ?? Number(process.env.ANDROID_VERSION_CODE ?? 52),
    blockedPermissions: [
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_VISUAL_USER_SELECTED',
      ...(optimizedRelease ? ['android.permission.SYSTEM_ALERT_WINDOW'] : []),
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
    ['expo-dev-client', { addGeneratedScheme: !production }],
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
        // false blocks RECORD_AUDIO globally, including the speech plugin.
        microphonePermission:
          'AI Asistan’a sesli soru yazmak için mikrofon izni gerekir.',
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
    ['./plugins/withAndroidRelease.cjs', { production }],
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
    ['./plugins/withAndroidSplashApi33.cjs'],
    ['./plugins/withAndroidBranding.cjs'],
    [
      'expo-splash-screen',
      {
        backgroundColor: '#08070B',
        image: './assets/images/ekspersiz_logo.png',
        imageWidth: 112,
        resizeMode: 'contain',
      },
    ],
    [
      'expo-build-properties',
      {
        android: {
          usesCleartextTraffic: !production,
          cmakeVersion: '3.31.6',
          enableMinifyInReleaseBuilds: optimizedRelease,
          enableShrinkResourcesInReleaseBuilds: optimizedRelease,
          networkInspector: !optimizedRelease,
          // Room/WorkManager 2.5.0/2.9.1 instantiate these reflectively. AGP 9
          // R8 full mode does not retain constructors for class-only keep rules.
          extraProguardRules: [
            '-keep class * extends androidx.room.RoomDatabase { <init>(); }',
            '-keep class * extends androidx.work.InputMerger { <init>(); }',
          ].join('\n'),
        },
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
    appVariant: production ? 'production' : 'development',
    androidFirebase: !!process.env.GOOGLE_SERVICES_FILE,
    iosFirebase: !!process.env.GOOGLE_SERVICES_PLIST,
    androidMaps: !!process.env.EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY,
    iosMaps: !!process.env.EXPO_PUBLIC_GOOGLE_MAPS_IOS_API_KEY,
  },
};
export default config;
