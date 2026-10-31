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

test('Play and backend checks start together and preserve mandatory backend policy', async () => {
  let complete!: (value: unknown) => void;
  jest.mocked(api.request).mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        complete = resolve;
      }),
  );
  mockInfo.mockRejectedValueOnce(new Error('Play unavailable'));
  const pending = checkUpdate();
  expect(mockInfo).toHaveBeenCalledTimes(1);
  complete({ minimumAndroidBuild: 53 });
  await expect(pending).resolves.toEqual({ required: true, immediate: false });
});

test('backend unavailability does not hide a Play update', async () => {
  jest.mocked(api.request).mockRejectedValueOnce(new Error('offline'));
  mockInfo.mockResolvedValueOnce({
    available: true,
    inProgress: false,
    immediateAllowed: true,
  });
  await expect(checkUpdate()).resolves.toEqual({
    required: true,
    immediate: true,
  });
});

test('two unavailable services consume one five-second startup budget', async () => {
  jest.useFakeTimers();
  jest
    .mocked(api.request)
    .mockImplementationOnce(
      () =>
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('timeout')), 5000),
        ),
    );
  mockInfo.mockImplementationOnce(() => new Promise(() => undefined));
  const result = checkUpdate();
  await jest.advanceTimersByTimeAsync(5000);
  await expect(result).resolves.toEqual({ required: false, immediate: false });
  expect(jest.getTimerCount()).toBe(0);
});
test('failed native update opens the installed application listing', async () => {
  mockImmediate.mockRejectedValueOnce(new Error('not installed by Play'));
  await performUpdate({ required: true, immediate: true });
  expect(Linking.openURL).toHaveBeenCalledWith(
    'https://play.google.com/store/apps/details?id=com.gorkem.ekspersiz.dev',
  );
});
