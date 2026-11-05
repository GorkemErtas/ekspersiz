export function assertPublicationSnapshot(
  env: NodeJS.ProcessEnv,
  root: string,
):
  | {
      runtimeVersion: string;
      environmentHash: string;
      exportHash?: string;
    }
  | undefined;
export function createPublicationSnapshot(
  env: NodeJS.ProcessEnv,
  root: string,
  expected: {
    runtimeVersion: string;
    environmentHash: string;
  },
): object;
export function sealPublicationSnapshot(
  env: NodeJS.ProcessEnv,
  root: string,
  exportHash: string,
): void;
export function snapshotPath(root: string): string;
