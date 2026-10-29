import { useQuery } from '@tanstack/react-query';
import { protectedKey, queryClient, useSession } from './runtime';
export function useResource<T>(
  resource: string,
  load: (signal: AbortSignal) => Promise<T>,
  enabled = true,
) {
  const state = useSession();
  return useQuery({
    queryKey: protectedKey(resource),
    queryFn: ({ signal }) => load(signal),
    enabled: !!state.profile && enabled,
  });
}
export function invalidate(...resources: string[]) {
  return queryClient.invalidateQueries({
    predicate: (query) =>
      resources.some((resource) =>
        String(query.queryKey.at(-1)).startsWith(resource),
      ),
  });
}
