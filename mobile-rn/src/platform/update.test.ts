import { Linking } from 'react-native';
import { api } from '../core/runtime';
import { checkUpdate, performUpdate } from './update';
jest.mock('react-native', () => ({
  Platform: { OS: 'android' },
  Linking: { openURL: jest.fn() },
}));
jest.mock('expo-application', () => ({
  applicationId: 'com.gorkem.ekspersiz.dev',
  nativeBuildVersion: '52',
}));
jest.mock('../core/runtime', () => ({ api: { request: jest.fn() } }));
jest.mock('./native', () => ({
  native: () => ({ playUpdateInfo: mockInfo, immediateUpdate: mockImmediate }),
}));
const mockInfo = jest.fn(),
  mockImmediate = jest.fn();
beforeEach(() => {
  jest.clearAllMocks();
  jest.mocked(api.request).mockResolvedValue({ minimumAndroidBuild: 53 });
  mockInfo.mockResolvedValue({
    available: false,
    inProgress: false,
    immediateAllowed: false,
  });
});
afterEach(() => jest.useRealTimers());
test('a stalled Play task falls back to backend policy within five seconds', async () => {
  jest.useFakeTimers();
  mockInfo.mockImplementationOnce(() => new Promise(() => undefined));
  const result = checkUpdate();
  await jest.advanceTimersByTimeAsync(5000);
  await expect(result).resolves.toEqual({ required: true, immediate: false });
  expect(jest.getTimerCount()).toBe(0);
});
test('an interrupted immediate update is resumable', async () => {
  mockInfo.mockResolvedValue({
    available: false,
    inProgress: true,
    immediateAllowed: false,
  });
  await expect(checkUpdate()).resolves.toEqual({
    required: true,
    immediate: true,
  });
});
test('failed native update opens the installed application listing', async () => {
  mockImmediate.mockRejectedValueOnce(new Error('not installed by Play'));
  await performUpdate({ required: true, immediate: true });
  expect(Linking.openURL).toHaveBeenCalledWith(
    'https://play.google.com/store/apps/details?id=com.gorkem.ekspersiz.dev',
  );
});
