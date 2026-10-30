import { Buffer } from 'node:buffer';
import { TextEncoder } from 'node:util';
import { convertFormDataAsync } from 'expo/build/winter/fetch/convertFormData';
import fixtures from '../../visual/fixtures.json';
import { inspections } from './services';
const { installFormDataPatch } = jest.requireActual<
  typeof import('expo/build/winter/FormData')
>('expo/build/winter/FormData');
const jpeg = new Uint8Array([255, 216, 255, 217]),
  mockRequest = jest.fn<Promise<typeof fixtures.inspection>, [string, unknown]>(
    async () => fixtures.inspection,
  );
jest.mock('./runtime', () => ({
  api: {
    request: (path: string, options: unknown) => mockRequest(path, options),
  },
  session: {},
}));
jest.mock('expo-file-system', () => ({
  File: class {
    readonly name = 'prepared-native.jpg';
    readonly type = 'image/jpeg';
    bytes() {
      return Promise.resolve(new Uint8Array([255, 216, 255, 217]));
    }
  },
}));
const originalForm = globalThis.FormData,
  originalEncoder = globalThis.TextEncoder;
const NativeFormData = jest.requireActual<{ default: typeof FormData }>(
  'react-native/Libraries/Network/FormData',
).default;
beforeEach(() => {
  mockRequest.mockClear();
  globalThis.FormData = installFormDataPatch(
    NativeFormData,
  ) as unknown as typeof FormData;
  globalThis.TextEncoder = TextEncoder as typeof globalThis.TextEncoder;
});
afterEach(() => {
  globalThis.FormData = originalForm;
  globalThis.TextEncoder = originalEncoder;
});
test.each([false, true])(
  'photo upload serializes real file bytes through Expo 58 multipart (context=%s)',
  async (context) => {
    await inspections.upload(1, 'file:///private/prepared-native.jpg', context);
    const [path, options] = mockRequest.mock.calls[0] as unknown as [
      string,
      { body: FormData; method: string },
    ];
    expect(path).toBe(`/inspections/1/${context ? 'context-image' : 'image'}`);
    expect(options.method).toBe('POST');
    const wire = await convertFormDataAsync(options.body, 'fixture-boundary'),
      bytes = Buffer.from(wire.body);
    expect(bytes.toString('latin1')).toContain(
      'name="image"; filename="prepared-native.jpg"',
    );
    expect(bytes.toString('latin1')).toContain('content-type: image/jpeg');
    expect(bytes.includes(Buffer.from(jpeg))).toBe(true);
  },
);

test('two-photo validation waits for the shared reservation before starting the second request', async () => {
  let release!: (value: typeof fixtures.inspection) => void;
  mockRequest.mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        release = resolve;
      }),
  );
  const checking = inspections.checkPhotos(1);
  await Promise.resolve();
  expect(mockRequest).toHaveBeenCalledTimes(1);
  expect(mockRequest.mock.calls[0]![0]).toBe(
    '/inspections/1/context-image-quality',
  );
  release(fixtures.inspection);
  await checking;
  expect(mockRequest.mock.calls.map(([path]) => path)).toEqual([
    '/inspections/1/context-image-quality',
    '/inspections/1/image-quality',
  ]);
});

test('a failed first photo validation does not dispatch a second request', async () => {
  mockRequest.mockRejectedValueOnce(new Error('validation unavailable'));
  await expect(inspections.checkPhotos(1)).rejects.toThrow(
    'validation unavailable',
  );
  expect(mockRequest).toHaveBeenCalledTimes(1);
});
