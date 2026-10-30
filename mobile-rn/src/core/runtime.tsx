import { QueryClient } from '@tanstack/react-query';
import * as SecureStore from 'expo-secure-store';
import { useSyncExternalStore } from 'react';
import { Api } from './api';
import { Session } from './session';
import { clearProtectedResources } from './protectedResources';
import Constants from 'expo-constants';
import { apiBaseUrl } from './environment';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 30_000, retry: false, refetchOnWindowFocus: false },
    mutations: { retry: false },
  },
});
export const session = new Session(
  {
    get: (key) => SecureStore.getItemAsync(key),
    set: (key, value) => SecureStore.setItemAsync(key, value),
    remove: (key) => SecureStore.deleteItemAsync(key),
  },
  () => {
    void queryClient.cancelQueries();
    queryClient.clear();
    clearProtectedResources();
  },
);
export const api = new Api(
  apiBaseUrl(
    process.env.EXPO_PUBLIC_API_BASE_URL,
    Constants.expoConfig?.extra?.appVariant,
  ),
  session,
);
export const useSession = () =>
  useSyncExternalStore(
    session.subscribe,
    session.getSnapshot,
    session.getSnapshot,
  );
export const protectedKey = (resource: string) => {
  const state = session.getSnapshot();
  return [
    state.profile?.id,
    state.workspace,
    state.workspace === 'BUSINESS' ? state.profile?.businessAccount?.id : null,
    state.generation,
    resource,
  ];
};
