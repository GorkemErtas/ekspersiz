const cleanups = new Set<() => void>();
const mediaCleanups = new Set<() => void>();
export function registerMediaCleanup(cleanup: () => void) {
  mediaCleanups.add(cleanup);
  return () => mediaCleanups.delete(cleanup);
}
export function clearProtectedMedia() {
  for (const cleanup of mediaCleanups) {
    try {
      cleanup();
    } catch {
      /* No old path is republished after invalidation. */
    }
  }
}
export function registerProtectedCleanup(cleanup: () => void) {
  cleanups.add(cleanup);
  return () => cleanups.delete(cleanup);
}
export function clearProtectedResources() {
  for (const cleanup of cleanups) {
    try {
      cleanup();
    } catch {
      /* Scope guards still prevent stale publication if cleanup is unavailable. */
    }
  }
}
