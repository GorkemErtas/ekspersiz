const mockState: {
  generation: number;
  profile: { id: number } | null;
  token: string | null;
} = { generation: 1, profile: { id: 7 }, token: 'jwt' };
const mockRequest = jest.fn(async (): Promise<void> => undefined);
const mockInvalidate = jest.fn();
const mockHandlers: {
  refresh?: () => void;
  message?: () => void;
  open?: (event: { data: Record<string, string> }) => void;
} = {};
const mockPermission = jest.fn(async () => 1),
  mockDeleteToken = jest.fn(async (): Promise<void> => undefined),
  mockAutoInit = jest.fn(async () => undefined),
  mockSubscribe = jest.fn(),
  mockApns = jest.fn(async (): Promise<string | null> => 'apns-token'),
  mockToken = jest.fn(async () => 'fcm-token');
jest.mock('expo-constants', () => ({
  __esModule: true,
  default: {
    expoConfig: { extra: { androidFirebase: true, iosFirebase: true } },
  },
}));
jest.mock('react-native', () => ({
  Platform: { OS: 'ios', Version: 36 },
  PermissionsAndroid: {
    request: jest.fn(async () => 'granted'),
    PERMISSIONS: { POST_NOTIFICATIONS: 'notifications' },
    RESULTS: { GRANTED: 'granted' },
  },
}));
jest.mock('../core/runtime', () => ({
  session: {
    subscribe: mockSubscribe,
    getSnapshot: () => mockState,
    check: (generation: number) => {
      if (generation !== mockState.generation) throw new Error('stale');
    },
  },
  api: { request: mockRequest },
  queryClient: { invalidateQueries: mockInvalidate },
}));
jest.mock('@react-native-firebase/messaging', () => ({
  getMessaging: () => ({}),
  AuthorizationStatus: { AUTHORIZED: 1, PROVISIONAL: 2 },
  requestPermission: mockPermission,
  isDeviceRegisteredForRemoteMessages: () => true,
  registerDeviceForRemoteMessages: jest.fn(),
  getAPNSToken: mockApns,
  getToken: mockToken,
  deleteToken: mockDeleteToken,
  setAutoInitEnabled: mockAutoInit,
  onTokenRefresh: (_: unknown, callback: () => void) => {
    mockHandlers.refresh = callback;
    return jest.fn();
  },
  onMessage: (_: unknown, callback: () => void) => {
    mockHandlers.message = callback;
    return jest.fn();
  },
  onNotificationOpenedApp: (
    _: unknown,
    callback: (event: { data: Record<string, string> }) => void,
  ) => {
    mockHandlers.open = callback;
    return jest.fn();
  },
  getInitialNotification: async () => null,
}));
let push: typeof import('./push');
beforeEach(() => {
  jest.resetModules();
  jest.clearAllMocks();
  mockState.generation = 1;
  mockState.profile = { id: 7 };
  mockState.token = 'jwt';
  mockPermission.mockImplementation(async () => 1);
  mockApns.mockImplementation(async () => 'apns-token');
  mockToken.mockImplementation(async () => 'fcm-token');
  mockRequest.mockImplementation(async () => undefined);
  mockDeleteToken.mockImplementation(async () => undefined);
  jest.isolateModules(() => {
    push = jest.requireActual<typeof import('./push')>('./push');
  });
});
afterEach(() => jest.useRealTimers());
test('concurrent registration writes one FCM token, never the APNS token', async () => {
  await Promise.all([push.registerDevice(), push.registerDevice()]);
  expect(mockRequest).toHaveBeenCalledTimes(1);
  expect(mockRequest).toHaveBeenCalledWith(
    '/notifications/devices',
    expect.objectContaining({ body: { token: 'fcm-token', platform: 'IOS' } }),
  );
});
test('logout waits for an in-flight registration and removes that token afterward', async () => {
  let resolve!: () => void;
  mockRequest.mockImplementationOnce(
    () =>
      new Promise<void>((done) => {
        resolve = done;
      }),
  );
  const registering = push.registerDevice();
  for (let tick = 0; tick < 12 && !resolve; tick++) await Promise.resolve();
  expect(resolve).toBeDefined();
  const logout = push.unregisterDevice();
  resolve();
  await registering;
  await logout;
  expect(mockRequest.mock.calls[1]).toEqual([
    '/notifications/devices?token=fcm-token',
    expect.objectContaining({ method: 'DELETE' }),
  ]);
  await push.registerDevice();
  expect(mockRequest).toHaveBeenCalledTimes(2);
});
test('a permission dialog completed after logout cannot register the former session', async () => {
  let grant!: (value: number) => void;
  mockPermission.mockImplementationOnce(
    () =>
      new Promise<number>((done) => {
        grant = done;
      }),
  );
  const registering = push.registerDevice();
  await push.unregisterDevice();
  grant(1);
  await registering;
  expect(mockRequest).not.toHaveBeenCalled();
});
test('late callbacks from a previous workspace cannot navigate or invalidate a new session', async () => {
  const open = jest.fn(),
    unsubscribe = push.watchPush(open);
  mockState.generation++;
  mockHandlers.open?.({ data: { vehicleId: '1' } });
  mockHandlers.refresh?.();
  mockHandlers.message?.();
  await Promise.resolve();
  expect(open).not.toHaveBeenCalled();
  expect(mockInvalidate).not.toHaveBeenCalled();
  expect(mockPermission).not.toHaveBeenCalled();
  unsubscribe();
});
test('iOS waits briefly for APNS before asking Firebase for its FCM token', async () => {
  jest.useFakeTimers();
  mockApns.mockResolvedValueOnce(null);
  const registering = push.registerDevice();
  await jest.advanceTimersByTimeAsync(500);
  await registering;
  expect(mockApns).toHaveBeenCalledTimes(2);
  expect(mockToken).toHaveBeenCalledTimes(1);
});
test('iOS reports missing APNS registration and never sends an APNS/placeholder token', async () => {
  jest.useFakeTimers();
  mockApns.mockResolvedValue(null);
  const registering = push.registerDevice(),
    result = expect(registering).rejects.toThrow('henüz tamamlanamadı');
  await jest.advanceTimersByTimeAsync(2500);
  await result;
  expect(mockApns).toHaveBeenCalledTimes(5);
  expect(mockToken).not.toHaveBeenCalled();
  expect(mockRequest).not.toHaveBeenCalled();
});

test('logout disables auto-init and invalidates the native token even when backend removal fails', async () => {
  await push.registerDevice();
  mockRequest.mockRejectedValueOnce(new Error('offline'));
  await push.unregisterDevice();
  expect(mockAutoInit).toHaveBeenLastCalledWith(expect.anything(), false);
  expect(mockDeleteToken).toHaveBeenCalledTimes(1);
});

test('a restarted process can invalidate its native token without an in-memory registration', async () => {
  await push.unregisterDevice();
  expect(mockDeleteToken).toHaveBeenCalledTimes(1);
  expect(mockRequest).not.toHaveBeenCalled();
});

test('workspace changes do not POST an unchanged user/device token again', async () => {
  await push.registerDevice();
  mockState.generation++;
  await push.registerDevice();
  expect(mockRequest).toHaveBeenCalledTimes(1);
});

test('failed Firebase token deletion never blocks local logout', async () => {
  mockDeleteToken.mockRejectedValueOnce(new Error('offline'));
  await expect(push.unregisterDevice()).resolves.toBeUndefined();
});

test('a stalled Firebase cleanup cannot hold local logout indefinitely', async () => {
  jest.useFakeTimers();
  mockDeleteToken.mockImplementationOnce(
    () => new Promise<void>(() => undefined),
  );
  const cleanup = push.unregisterDevice();
  await jest.advanceTimersByTimeAsync(5000);
  await expect(cleanup).resolves.toBeUndefined();
  expect(jest.getTimerCount()).toBe(0);
});

test('a server-driven session loss invalidates FCM without using the next account credentials', async () => {
  await push.registerDevice();
  mockState.profile = null;
  mockState.token = null;
  mockState.generation++;
  mockSubscribe.mock.calls[0]![0]();
  for (let tick = 0; tick < 30; tick++) await Promise.resolve();
  expect(mockDeleteToken).toHaveBeenCalledTimes(1);
  expect(mockRequest).toHaveBeenCalledTimes(1);
});

test('the next account cannot obtain/register a token until the former token deletion finishes', async () => {
  await push.registerDevice();
  let finish!: () => void;
  mockDeleteToken.mockImplementationOnce(
    () =>
      new Promise<void>((resolve) => {
        finish = resolve;
      }),
  );
  const unregistering = push.unregisterDevice();
  for (let tick = 0; tick < 20 && !finish; tick++) await Promise.resolve();
  expect(finish).toBeDefined();
  mockState.profile = { id: 8 };
  mockState.generation++;
  mockToken.mockResolvedValue('next-user-token');
  const registering = push.registerDevice();
  for (let tick = 0; tick < 20; tick++) await Promise.resolve();
  expect(mockToken).toHaveBeenCalledTimes(1);
  finish();
  await unregistering;
  await registering;
  expect(mockRequest).toHaveBeenLastCalledWith(
    '/notifications/devices',
    expect.objectContaining({
      body: { token: 'next-user-token', platform: 'IOS' },
    }),
  );
});
