import type { Api } from '../../core/api';
import { Session } from '../../core/session';
import { AssistantService, historyContent } from './AssistantService';
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
    't',
    {
      id: 1,
      fullName: 'Deniz',
      email: 'd@example.com',
      subscriptionPlan: 'FREE',
      businessAccount: null,
    },
    session.beginLogin(),
  );
  const request = jest
      .fn()
      .mockResolvedValue({ answer: 'Yanıt', remainingToday: 2, sources: [] }),
    uuid = jest
      .fn()
      .mockReturnValueOnce('uuid-1')
      .mockReturnValueOnce('uuid-2');
  return {
    session,
    request,
    uuid,
    service: new AssistantService({ request } as unknown as Api, session, uuid),
  };
}
test('failed identical chat payload reuses its requestId; a successful new question gets a new ID', async () => {
  const x = await setup();
  x.request.mockRejectedValueOnce(new Error('timeout'));
  await expect(x.service.ask('Motor sesi?', 1, [])).rejects.toThrow('timeout');
  await x.service.ask('Motor sesi?', 1, []);
  await x.service.ask('Yağ değişimi?', 1, []);
  expect(x.request.mock.calls.map((call) => call[1].body.requestId)).toEqual([
    'uuid-1',
    'uuid-1',
    'uuid-2',
  ]);
});
test('history keeps the last six messages, retaining both ends and valid UTF-16 under the server limit', async () => {
  const x = await setup();
  const history = Array.from({ length: 9 }, (_, i) => ({
    role: 'user' as const,
    content: `${i} ${'🚗'.repeat(1500)} son`,
  }));
  await x.service.ask('Soru', undefined, history);
  const sent = x.request.mock.calls[0]![1].body;
  expect(sent.history).toHaveLength(6);
  expect(sent.history[0].content.startsWith('3 ')).toBe(true);
  for (const message of sent.history) {
    expect(message.content.length).toBeLessThanOrEqual(2000);
    expect(message.content.isWellFormed()).toBe(true);
    expect(message.content.endsWith(' son')).toBe(true);
  }
  expect(sent).not.toHaveProperty('vehicleId');
});
test('invalid question never sends a potentially paid request', async () => {
  const x = await setup();
  await expect(x.service.ask('x'.repeat(2001), undefined, [])).rejects.toThrow(
    '2000',
  );
  expect(x.request).not.toHaveBeenCalled();
});
test('short history content is unchanged', () =>
  expect(historyContent('Türkçe bakım sorusu')).toBe('Türkçe bakım sorusu'));
