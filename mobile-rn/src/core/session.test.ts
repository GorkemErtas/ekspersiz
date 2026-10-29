import { QueryClient } from '@tanstack/react-query';
import { parseProfile, type UserProfile } from './contracts';
import { Session, StaleSessionError, type SessionStorage } from './session';

export const user: UserProfile = {
  id: 1,
  fullName: 'Deniz Yılmaz',
  email: 'deniz@example.com',
  subscriptionPlan: 'BUSINESS',
  businessAccount: {
    id: 9,
    companyName: 'Deniz Otomotiv',
    role: 'OWNER',
    sandbox: false,
    workspaceAvailable: true,
    workspaceAccessStatus: 'ACTIVE',
  },
};
function setup() {
  const values = new Map<string, string>();
  const storage: SessionStorage = {
    get: jest.fn(async (key) => values.get(key) ?? null),
    set: jest.fn(async (key, value) => {
      values.set(key, value);
    }),
    remove: jest.fn(async (key) => {
      values.delete(key);
    }),
  };
  const query = new QueryClient();
  const clear = jest.fn(() => query.clear());
  return {
    values,
    storage,
    query,
    clear,
    session: new Session(storage, clear),
  };
}
async function login(session: Session, profile = user) {
  const generation = session.beginLogin();
  await session.authenticate('token', profile, generation);
}
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

test('membership and personal BUSINESS plan never imply available Business workspace', () => {
  const profile = parseProfile({
    ...user,
    businessAccount: {
      ...user.businessAccount,
      workspaceAccessStatus: 'EXPIRED',
    },
  });
  expect(profile.businessAccount?.workspaceAvailable).toBe(false);
});
test('unrecognized membership role fails closed', () => {
  expect(() =>
    parseProfile({
      ...user,
      businessAccount: { ...user.businessAccount, role: 'ADMIN' },
    }),
  ).toThrow();
});
test('new sessions honor only server-confirmed availability and saved PERSONAL preference', async () => {
  const { session, values } = setup();
  values.set('workspace.user.1', 'PERSONAL');
  await login(session);
  expect(session.getSnapshot().workspace).toBe('PERSONAL');
});
test('workspace publication follows authorization and evicts protected query data', async () => {
  const { session, query } = setup();
  await login(session);
  query.setQueryData(['private-report'], 'business report');
  const server = deferred<unknown>();
  const change = session.select('PERSONAL', () => server.promise);
  expect(session.getSnapshot().workspace).toBe('BUSINESS');
  server.resolve({ type: 'PERSONAL', userId: 1, businessId: null });
  await change;
  expect(query.getQueryData(['private-report'])).toBeUndefined();
  expect(session.getSnapshot().workspace).toBe('PERSONAL');
});
test('workspace identity mismatch rejects without publishing', async () => {
  const { session } = setup();
  await login(session);
  await expect(
    session.select('PERSONAL', async () => ({
      type: 'PERSONAL',
      userId: 2,
      businessId: null,
    })),
  ).rejects.toThrow();
  expect(session.getSnapshot().workspace).toBe('BUSINESS');
});
test('expired Business falls back to PERSONAL without deleting membership or token', async () => {
  const { session } = setup();
  await login(session);
  session.revokeBusiness();
  expect(session.getSnapshot()).toMatchObject({
    workspace: 'PERSONAL',
    token: 'token',
    profile: { businessAccount: { id: 9, workspaceAvailable: false } },
  });
  await expect(session.select('BUSINESS', jest.fn())).rejects.toThrow();
});
test('plan refresh during reconciliation retains request generation', async () => {
  const { session } = setup();
  await login(session);
  const generation = session.getSnapshot().generation;
  await session.refreshProfile(async () => ({
    ...user,
    subscriptionPlan: 'FREE',
  }));
  expect(session.getSnapshot().generation).toBe(generation);
});
test('role change cancels requests and clears protected data', async () => {
  const { session } = setup();
  await login(session);
  const controller = new AbortController();
  session.track(controller);
  await session.refreshProfile(async () => ({
    ...user,
    businessAccount: { ...user.businessAccount!, role: 'MEMBER' },
  }));
  expect(controller.signal.aborted).toBe(true);
});
test('older profile response cannot overwrite a newer refresh', async () => {
  const { session } = setup();
  await login(session);
  const old = deferred<UserProfile>();
  const request = session.refreshProfile(() => old.promise);
  await session.refreshProfile(async () => ({
    ...user,
    fullName: 'Yeni İsim',
  }));
  old.resolve(user);
  await expect(request).rejects.toBeInstanceOf(StaleSessionError);
  expect(session.getSnapshot().profile?.fullName).toBe('Yeni İsim');
});
test('logout cancels in-flight requests and blocks stale login acceptance', async () => {
  const { session } = setup();
  const generation = session.beginLogin();
  const controller = new AbortController();
  session.track(controller);
  await session.logout();
  expect(controller.signal.aborted).toBe(true);
  await expect(
    session.authenticate('old', user, generation),
  ).rejects.toBeInstanceOf(StaleSessionError);
});
test('secure writes serialize so pending login cannot resurrect credentials after logout', async () => {
  const { session, storage, values } = setup();
  const gate = deferred<void>();
  storage.set = jest.fn(async (key, value) => {
    await gate.promise;
    values.set(key, value);
  });
  const generation = session.beginLogin();
  const acceptance = session.authenticate('old', user, generation);
  await Promise.resolve();
  await Promise.resolve();
  const rejection =
    expect(acceptance).rejects.toBeInstanceOf(StaleSessionError);
  const logout = session.logout();
  gate.resolve();
  await rejection;
  await logout;
  expect(values.has('access_token')).toBe(false);
});
test('stale workspace authorization cannot cross user login', async () => {
  const { session } = setup();
  await login(session);
  const authorization = deferred<unknown>();
  const switchRequest = session.select('PERSONAL', () => authorization.promise);
  await login(session, { ...user, id: 2, businessAccount: null });
  authorization.resolve({ type: 'PERSONAL', userId: 1, businessId: null });
  await expect(switchRequest).rejects.toBeInstanceOf(StaleSessionError);
  expect(session.getSnapshot().profile?.id).toBe(2);
});
