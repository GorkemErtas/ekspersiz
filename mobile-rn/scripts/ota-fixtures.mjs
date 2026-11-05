// Synthetic configuration only. Never used by the app or deployment workflows.
import { productionApi, easProject } from '../config/productionEnvironment.cjs';
export const publicEnv = (file = 'fixture.json') => ({
  APP_VARIANT: 'production',
  APP_CONFIG_MODE: 'ota',
  EXPO_NO_DOTENV: '1',
  EXPO_PUBLIC_API_BASE_URL: productionApi,
  EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY: 'goog_fixture',
  EXPO_PUBLIC_GOOGLE_MAPS_ANDROID_API_KEY: 'AIza' + 'x'.repeat(35),
  EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID: 'fixture-web.apps.googleusercontent.com',
  GOOGLE_SERVICES_FILE: file,
  ANDROID_VERSION_NAME: '1.0.3',
  ANDROID_VERSION_CODE: '55',
  EXPO_UPDATES_ENABLED: '1',
  EXPO_UPDATES_PROJECT_ID: easProject.id,
  EXPO_UPDATES_CHANNEL: 'staging',
});
export const firebase = () => ({
  project_info: { project_id: 'synthetic-config-test', project_number: '123' },
  client: [
    {
      client_info: {
        android_client_info: { package_name: 'com.gorkem.ekspersiz' },
      },
      oauth_client: [
        {
          client_type: 3,
          client_id: publicEnv().EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID,
        },
        {
          client_type: 1,
          android_info: {
            package_name: 'com.gorkem.ekspersiz',
            certificate_hash: '12'.repeat(20),
          },
        },
      ],
    },
  ],
});
