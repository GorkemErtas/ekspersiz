export const productionPackage: 'com.gorkem.ekspersiz';
export const productionApi: string;
export const releaseEnvironmentNames: Set<string>;
export function normalizeFingerprint(value: string, bytes: number): string;
export function androidReleaseConfig(
  env: Record<string, string | undefined>,
  projectRoot: string,
  read?: (path: string) => string,
  exists?: (path: string) => boolean,
): {
  versionName: string;
  versionCode: number;
  googleServicesFile: string;
  signingPropertiesFile: string;
  signingBaseDirectory: string;
  sha1: string;
  sha256: string;
  firebaseProject: string;
};
