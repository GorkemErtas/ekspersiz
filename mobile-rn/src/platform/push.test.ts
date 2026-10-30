const mockState = { generation: 1, profile: { id: 7 }, token: 'jwt' };
const mockRequest = jest.fn(async (): Promise<void> => undefined);
const mockInvalidate = jest.fn();
const mockHandlers: {
  refresh?: () => void;
  message?: () => void;
  open?: (event: { data: Record<string, string> }) => void;
} = {};
const mockPermission = jest.fn(async () => 1),
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
  mockPermission.mockImplementation(async () => 1);
  mockApns.mockImplementation(async () => 'apns-token');
  mockToken.mockImplementation(async () => 'fcm-token');
  mockRequest.mockImplementation(async () => undefined);
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
