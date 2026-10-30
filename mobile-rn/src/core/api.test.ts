import { Api, ApiError } from './api';
import { Session, StaleSessionError } from './session';
import type { UserProfile } from './contracts';

const user: UserProfile = {
  id: 1,
  fullName: 'Deniz',
  email: 'deniz@example.com',
  subscriptionPlan: 'FREE',
  businessAccount: {
    id: 9,
    companyName: 'Şirket',
    role: 'MEMBER',
    sandbox: false,
    workspaceAvailable: true,
    workspaceAccessStatus: 'ACTIVE',
  },
};
function reply(
  body: unknown,
  status = 200,
  headers: Record<string, string> = { 'x-workspace': 'BUSINESS' },
): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: (key: string) => headers[key.toLowerCase()] ?? null },
    text: async () => (body === undefined ? '' : JSON.stringify(body)),
  } as Response;
}
async function setup() {
  const session = new Session(
    {
      get: async () => null,
      set: async () => undefined,
      remove: async () => undefined,
    },
    jest.fn(),
  );
  const generation = session.beginLogin();
  await session.authenticate('jwt', user, generation);
  const transport = jest.fn<
    typeof fetch extends (...args: infer A) => infer R ? R : never,
    Parameters<typeof fetch>
  >();
  const api = new Api('http://localhost:8080/api/v1', session, transport);
  return { api, session, transport };
}
test('authenticated requests send bearer and selected workspace headers', async () => {
  const { api, transport } = await setup();
  transport.mockResolvedValue(reply([]));
  await api.request('/vehicles');
  expect(transport).toHaveBeenCalledWith(
    'http://localhost:8080/api/v1/vehicles',
    expect.objectContaining({
      headers: expect.objectContaining({
        Authorization: 'Bearer jwt',
        'X-Workspace': 'BUSINESS',
      }),
    }),
  );
});
test('workspace response echo is mandatory before data is exposed', async () => {
  const { api, transport } = await setup();
  transport.mockResolvedValue(reply([], 200, {}));
  await expect(api.request('/vehicles')).rejects.toMatchObject({ status: 503 });
});
test('unauthenticated login has no bearer or workspace and bad credentials do not invalidate a session', async () => {
  const { api, transport, session } = await setup();
  transport.mockResolvedValue(reply({ message: 'Bad credentials' }, 401));
  await expect(
    api.request('/auth/login', { auth: false, method: 'POST', body: {} }),
  ).rejects.toBeInstanceOf(ApiError);
  const headers = transport.mock.calls[0]?.[1]?.headers;
  expect(headers).not.toHaveProperty('Authorization');
  expect(headers).not.toHaveProperty('X-Workspace');
  expect(session.getSnapshot().token).toBe('jwt');
});
test('old 401 after user changes cannot log out the new account', async () => {
  const { api, transport, session } = await setup();
  let finish!: (response: Response) => void;
  transport.mockImplementation(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  const request = api.request('/vehicles');
  const generation = session.beginLogin();
  await session.authenticate('new', { ...user, id: 2 }, generation);
  finish(reply({}, 401));
  await expect(request).rejects.toBeInstanceOf(StaleSessionError);
  expect(session.getSnapshot().token).toBe('new');
});
test('old 401 after password token rotation cannot invalidate replacement token', async () => {
  const { api, transport, session } = await setup();
  let finish!: (response: Response) => void;
  transport.mockImplementation(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  const request = api.request('/vehicles');
  await session.rotateToken('rotated', session.getSnapshot().generation);
  finish(reply({}, 401));
  await expect(request).rejects.toBeInstanceOf(StaleSessionError);
  expect(session.getSnapshot().token).toBe('rotated');
});
test('WORKSPACE_UNAVAILABLE preserves personal access and membership', async () => {
  const { api, transport, session } = await setup();
  transport.mockResolvedValue(
    reply(
      {
        message: 'Şirket erişimi sona erdi.',
        validationErrors: { code: 'WORKSPACE_UNAVAILABLE' },
      },
      403,
    ),
  );
  await expect(api.request('/vehicles')).rejects.toMatchObject({
    code: 'WORKSPACE_UNAVAILABLE',
  });
  expect(session.getSnapshot()).toMatchObject({
    token: 'jwt',
    workspace: 'PERSONAL',
    profile: { businessAccount: { id: 9 } },
  });
});
test('change-password persists replacement token from response header', async () => {
  const { api, transport, session } = await setup();
  transport.mockResolvedValue(
    reply(undefined, 204, { authorization: 'Bearer rotated' }),
  );
  await api.request('/auth/change-password', { method: 'POST', body: {} });
  expect(session.getSnapshot().token).toBe('rotated');
});
test('older password-change server requires safe re-login', async () => {
  const { api, transport, session } = await setup();
  transport.mockResolvedValue(reply(undefined, 204, {}));
  await api.request('/auth/change-password', { method: 'POST', body: {} });
  expect(session.getSnapshot().token).toBeNull();
});
test('protected 401 immediately invalidates local session', async () => {
  const { api, transport, session } = await setup();
  transport.mockResolvedValue(reply(undefined, 401));
  await expect(api.request('/vehicles')).rejects.toMatchObject({ status: 401 });
  expect(session.getSnapshot().profile).toBeNull();
});
test('mutations are never automatically retried', async () => {
  const { api, transport } = await setup();
  transport.mockRejectedValue(new TypeError('offline'));
  await expect(
    api.request('/inspections/1/analyze', { method: 'POST' }),
  ).rejects.toMatchObject({ status: 0 });
  expect(transport).toHaveBeenCalledTimes(1);
});
test('absolute URLs cannot receive credentials', async () => {
  const { api, transport } = await setup();
  await expect(
    api.request('https://external.invalid/vehicles'),
  ).rejects.toThrow();
  expect(transport).not.toHaveBeenCalled();
});
