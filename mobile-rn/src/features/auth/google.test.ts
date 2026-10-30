import { api, session } from '../../core/runtime';
import { GoogleSignin } from '@react-native-google-signin/google-signin';
import { googleLogin } from './auth';

jest.mock('../../core/runtime', () => ({
  api: { request: jest.fn() },
  session: {
    beginLogin: jest.fn(() => 7),
    check: jest.fn(),
    authenticate: jest.fn(async () => undefined),
  },
}));
jest.mock('@react-native-google-signin/google-signin', () => ({
  GoogleSignin: {
    configure: jest.fn(),
    hasPlayServices: jest.fn(async () => true),
    signIn: jest.fn(),
    getCurrentUser: jest.fn(() => null),
    signOut: jest.fn(async () => undefined),
  },
  isSuccessResponse: (response: { type: string }) =>
    response.type === 'success',
}));
const originalClientId = process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID;
beforeEach(() => {
  jest.clearAllMocks();
  process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID = 'test-client-id';
});
afterAll(() => {
  if (originalClientId === undefined)
    delete process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID;
  else process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID = originalClientId;
});
test('missing native login configuration produces a real error before SDK/backend activity', async () => {
  delete process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID;
  await expect(googleLogin()).rejects.toThrow('yapılandırması');
  expect(GoogleSignin.signIn).not.toHaveBeenCalled();
  expect(api.request).not.toHaveBeenCalled();
});
test('cancelled Google consent never authenticates or posts an empty identity token', async () => {
  jest
    .mocked(GoogleSignin.signIn)
    .mockResolvedValue({ type: 'cancelled', data: null });
  await googleLogin();
  expect(api.request).not.toHaveBeenCalled();
  expect(session.authenticate).not.toHaveBeenCalled();
});
test('native ID token is exchanged for server credentials; Google success alone grants no session', async () => {
  jest.mocked(GoogleSignin.signIn).mockResolvedValue({
    type: 'success',
    data: { idToken: 'google-id-token' },
  } as Awaited<ReturnType<typeof GoogleSignin.signIn>>);
  jest.mocked(api.request).mockResolvedValue({
    accessToken: 'server-jwt',
    userId: 1,
    fullName: 'Deniz',
    email: 'deniz@example.com',
    subscriptionPlan: 'FREE',
    businessAccount: null,
  });
  await googleLogin();
  expect(api.request).toHaveBeenCalledWith('/auth/google', {
    method: 'POST',
    auth: false,
    body: { idToken: 'google-id-token' },
  });
  expect(session.authenticate).toHaveBeenCalledWith(
    'server-jwt',
    expect.objectContaining({ id: 1 }),
    7,
  );
});

test('a retained Google account is signed out locally before the account chooser opens', async () => {
  jest
    .mocked(GoogleSignin.getCurrentUser)
    .mockReturnValueOnce({ user: { id: 'previous-account' } } as ReturnType<
      typeof GoogleSignin.getCurrentUser
    >);
  jest
    .mocked(GoogleSignin.signIn)
    .mockResolvedValue({ type: 'cancelled', data: null });
  await googleLogin();
  expect(GoogleSignin.signOut).toHaveBeenCalledTimes(1);
  expect(
    jest.mocked(GoogleSignin.signOut).mock.invocationCallOrder[0],
  ).toBeLessThan(jest.mocked(GoogleSignin.signIn).mock.invocationCallOrder[0]!);
});

test('a session change while waiting for Play services prevents an obsolete Google sheet', async () => {
  jest.mocked(session.check).mockImplementationOnce(() => {
    throw new Error('stale');
  });
  await expect(googleLogin()).rejects.toThrow('stale');
  expect(GoogleSignin.signIn).not.toHaveBeenCalled();
  expect(api.request).not.toHaveBeenCalled();
});
