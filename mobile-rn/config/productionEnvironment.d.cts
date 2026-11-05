export const productionPackage: 'com.gorkem.ekspersiz';
export const productionApi: string;
export const easProject: Readonly<{ owner: string; slug: string; id: string }>;
export const publicEnvironmentNames: readonly string[];
export const signingEnvironmentNames: readonly string[];
export function required(env: NodeJS.ProcessEnv, name: string): string;
export function productionEnvironmentConfig(
  env: NodeJS.ProcessEnv,
  root: string,
  read?: (path: string) => string,
): {
  versionName: string;
  versionCode: number;
  googleServicesFile: string;
  firebase: { project_info: { project_id: string; project_number: string } };
  oauth: Record<string, unknown>[];
  environmentHash: string;
};
