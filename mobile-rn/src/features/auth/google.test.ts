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
