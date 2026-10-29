import * as Location from 'expo-location';
import { currentPosition } from './location';
jest.mock('expo-location', () => ({
  Accuracy: { High: 4 },
  getLastKnownPositionAsync: jest.fn(),
  watchPositionAsync: jest.fn(),
}));
const known = jest.mocked(Location.getLastKnownPositionAsync),
  watch = jest.mocked(Location.watchPositionAsync),
  point: Location.LocationObject = {
    timestamp: 1,
    coords: {
      latitude: 41,
      longitude: 29,
      altitude: null,
      accuracy: 5,
      altitudeAccuracy: null,
      heading: null,
      speed: null,
    },
  };
beforeEach(() => {
  jest.clearAllMocks();
  known.mockResolvedValue(null);
});
afterEach(() => jest.useRealTimers());
test('a fresh fix avoids opening another GPS subscription', async () => {
  known.mockResolvedValue(point);
  await expect(currentPosition(new AbortController().signal)).resolves.toBe(
    point,
  );
  expect(watch).not.toHaveBeenCalled();
});
test('the first fix resolves and removes the native subscription even if its handle arrives later', async () => {
  const remove = jest.fn();
  watch.mockImplementation(async (_, callback) => {
    callback(point);
    return { remove };
  });
  await expect(currentPosition(new AbortController().signal)).resolves.toBe(
    point,
  );
  await Promise.resolve();
  expect(remove).toHaveBeenCalledTimes(1);
});
test('GPS timeout releases the native subscription', async () => {
  jest.useFakeTimers();
  const remove = jest.fn();
  watch.mockResolvedValue({ remove });
  const result = expect(
    currentPosition(new AbortController().signal),
  ).rejects.toThrow('zamanında');
  await jest.advanceTimersByTimeAsync(20000);
  await result;
  expect(remove).toHaveBeenCalledTimes(1);
});
test('leaving the screen before native setup completes still disposes the eventual subscription', async () => {
  const controller = new AbortController(),
    remove = jest.fn();
  let ready!: (value: Location.LocationSubscription) => void;
  watch.mockImplementation(
    () =>
      new Promise((resolve) => {
        ready = resolve;
      }),
  );
  const request = currentPosition(controller.signal),
    result = expect(request).rejects.toThrow('iptal');
  await Promise.resolve();
  controller.abort();
  ready({ remove });
  await result;
  await Promise.resolve();
  expect(remove).toHaveBeenCalledTimes(1);
});
