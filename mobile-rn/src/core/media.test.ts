import { Api } from './api';
import { Session, StaleSessionError } from './session';
import { registerMediaCleanup } from './protectedResources';
async function setup() {
  const session = new Session(
    {
      get: async () => null,
      set: async () => undefined,
      remove: async () => undefined,
    },
    () => undefined,
  );
  await session.authenticate(
    'jwt',
    {
      id: 1,
      fullName: 'Deniz',
      email: 'd@example.com',
      subscriptionPlan: 'FREE',
      businessAccount: null,
    },
    session.beginLogin(),
  );
  const transport = jest.fn();
  return {
    session,
    transport,
    api: new Api('https://example.invalid/api/v1', session, transport),
  };
}
const response = (
  bytes: ArrayBuffer,
  headers: Record<string, string> = { 'x-workspace': 'PERSONAL' },
) =>
  ({
    ok: true,
    status: 200,
    headers: { get: (key: string) => headers[key.toLowerCase()] ?? null },
    arrayBuffer: jest.fn(async () => bytes),
  }) as unknown as Response;
test('a chunked response without content-length is cancelled at the byte limit', async () => {
  const x = await setup(),
    reply = response(new ArrayBuffer(0)),
    reader = {
      read: jest.fn().mockResolvedValue({
        done: false,
        value: new Uint8Array(6 * 1024 * 1024),
      }),
      cancel: jest.fn(async () => undefined),
      releaseLock: jest.fn(),
    };
  Object.defineProperty(reply, 'body', { value: { getReader: () => reader } });
  x.transport.mockResolvedValue(reply);
  await expect(
    x.api.request('/inspections/1/image', { binary: true }),
  ).rejects.toThrow('çok büyük');
  expect(reader.read).toHaveBeenCalledTimes(2);
  expect(reader.cancel).toHaveBeenCalledTimes(1);
  expect(reply.arrayBuffer).not.toHaveBeenCalled();
  expect(reader.releaseLock).toHaveBeenCalled();
});
test('streamed image chunks are joined without using an unbounded arrayBuffer read', async () => {
  const x = await setup(),
    reply = response(new ArrayBuffer(0)),
    reader = {
      read: jest
        .fn()
        .mockResolvedValueOnce({ done: false, value: new Uint8Array([1, 2]) })
        .mockResolvedValueOnce({ done: false, value: new Uint8Array([3]) })
        .mockResolvedValue({ done: true }),
      releaseLock: jest.fn(),
    };
  Object.defineProperty(reply, 'body', { value: { getReader: () => reader } });
  x.transport.mockResolvedValue(reply);
  const bytes = await x.api.request<ArrayBuffer>('/inspections/1/image', {
    binary: true,
  });
  expect(Array.from(new Uint8Array(bytes))).toEqual([1, 2, 3]);
  expect(reply.arrayBuffer).not.toHaveBeenCalled();
  expect(reader.releaseLock).toHaveBeenCalled();
});
test('protected bytes require the selected workspace echo', async () => {
  const x = await setup();
  x.transport.mockResolvedValue(
    response(new ArrayBuffer(2), { 'x-workspace': 'BUSINESS' }),
  );
  await expect(
    x.api.request('/inspections/1/image', { binary: true }),
  ).rejects.toThrow('alanını doğrulamadı');
});
test('oversized images are rejected before reading a declared large body', async () => {
  const x = await setup(),
    reply = response(new ArrayBuffer(1), {
      'x-workspace': 'PERSONAL',
      'content-length': String(11 * 1024 * 1024),
    });
  x.transport.mockResolvedValue(reply);
  await expect(
    x.api.request('/inspections/1/image', { binary: true }),
  ).rejects.toThrow();
  expect(reply.arrayBuffer).not.toHaveBeenCalled();
});
test('late binary body cannot escape a logout boundary', async () => {
  const x = await setup();
  let finish!: (value: ArrayBuffer) => void;
  const reply = response(new ArrayBuffer(1));
  reply.arrayBuffer = () =>
    new Promise((resolve) => {
      finish = resolve;
    });
  x.transport.mockResolvedValue(reply);
  const pending = x.api.request('/inspections/1/image', { binary: true });
  while (!finish) await Promise.resolve();
  await x.session.logout();
  finish(new ArrayBuffer(1));
  await expect(pending).rejects.toBeInstanceOf(StaleSessionError);
});
test('generic forbidden responses invalidate protected media independently of membership', async () => {
  const x = await setup(),
    clear = jest.fn(),
    dispose = registerMediaCleanup(clear);
  x.transport.mockResolvedValue({
    ok: false,
    status: 403,
    headers: { get: () => null },
    text: async () => JSON.stringify({ message: 'Forbidden' }),
  });
  await expect(x.api.request('/inspections/1')).rejects.toThrow('Forbidden');
  expect(clear).toHaveBeenCalledTimes(1);
  expect(x.session.getSnapshot().profile?.id).toBe(1);
  dispose();
});
