import { ApiError } from './api';
import { isRecord, parseProfile } from './contracts';
import { api, session } from './runtime';
import type {
  AppNotification,
  AssistantEntitlement,
  BillingOverview,
  BusinessMember,
  CreditOverview,
  DamageRecord,
  HistoryItem,
  Inspection,
  Maintenance,
  NearbyService,
  RecordInput,
  Reminder,
  Vehicle,
  VehicleOverview,
} from './models';
import { positiveId } from './models';

/** Decode collection/object envelopes before publishing server state. */
export function object<T>(value: unknown): T {
  if (!isRecord(value)) throw new Error('Sunucudan geçersiz veri alındı.');
  return value as T;
}
export function list<T>(value: unknown): T[] {
  if (!Array.isArray(value) || !value.every(isRecord))
    throw new Error('Sunucudan geçersiz liste alındı.');
  return value as T[];
}
async function get<T>(path: string, signal?: AbortSignal) {
  return object<T>(await api.request(path, { signal }));
}
async function getList<T>(path: string, signal?: AbortSignal) {
  return list<T>(await api.request(path, { signal }));
}
async function write<T>(
  path: string,
  body?: unknown,
  method: 'POST' | 'PUT' = 'POST',
  timeout?: number,
) {
  return object<T>(await api.request(path, { method, body, timeout }));
}
const idPath = (root: string, id: number) => `${root}/${positiveId(id)}`;
export const refreshProfile = () =>
  session.refreshProfile(async () =>
    parseProfile(await api.request('/auth/me')),
  );
export const vehicles = {
  list: (signal?: AbortSignal) => getList<Vehicle>('/vehicles', signal),
  get: (id: number, signal?: AbortSignal) =>
    get<Vehicle>(idPath('/vehicles', id), signal),
  save: (
    body: {
      plate: string;
      brand: string;
      model: string;
      modelYear: number;
      mileage: number;
      notes?: string | null;
      tracking?: unknown;
    },
    id?: number,
  ) =>
    write<Vehicle>(
      id ? idPath('/vehicles', id) : '/vehicles',
      {
        ...body,
        plate: body.plate
          .trim()
          .toUpperCase()
          .replace(/[^0-9A-Z]/g, ''),
        brand: body.brand.trim(),
        model: body.model.trim(),
      },
      id ? 'PUT' : 'POST',
    ),
  primary: (id: number) =>
    write<Vehicle>(`${idPath('/vehicles', id)}/primary`, {}, 'PUT'),
  delete: (id: number) =>
    api.request(idPath('/vehicles', id), { method: 'DELETE' }),
  overview: (id: number, signal?: AbortSignal) =>
    get<VehicleOverview>(`${idPath('/vehicles', id)}/overview`, signal),
  history: (id: number, signal?: AbortSignal) =>
    getList<HistoryItem>(`${idPath('/vehicles', id)}/history`, signal),
  maintenance: (id: number, signal?: AbortSignal) =>
    getList<Maintenance>(`${idPath('/vehicles', id)}/maintenance`, signal),
  reminders: (id: number, signal?: AbortSignal) =>
    getList<Reminder>(`${idPath('/vehicles', id)}/reminders`, signal),
  saveTracking: <T extends Maintenance | Reminder>(
    vehicleId: number,
    kind: 'maintenance' | 'reminders',
    body: unknown,
    recordId?: number,
  ) =>
    write<T>(
      `${idPath('/vehicles', vehicleId)}/${kind}${recordId ? `/${positiveId(recordId)}` : ''}`,
      body,
      recordId ? 'PUT' : 'POST',
    ),
  deleteTracking: (
    vehicleId: number,
    kind: 'maintenance' | 'reminders',
    recordId: number,
  ) =>
    api.request(
      `${idPath('/vehicles', vehicleId)}/${kind}/${positiveId(recordId)}`,
      { method: 'DELETE' },
    ),
  complete: (vehicleId: number, reminderId: number, completed: boolean) =>
    write<Reminder>(
      `${idPath('/vehicles', vehicleId)}/reminders/${positiveId(reminderId)}/completion?completed=${completed}`,
      {},
      'PUT',
    ),
};
export const inspections = {
  list: (signal?: AbortSignal) => getList<Inspection>('/inspections', signal),
  get: (id: number, signal?: AbortSignal) =>
    get<Inspection>(idPath('/inspections', id), signal),
  create: (
    vehicleId: number,
    city: string,
    latitude: number,
    longitude: number,
  ) =>
    write<Inspection>(
      `/inspections?${new URLSearchParams({ vehicleId: String(positiveId(vehicleId)), city: city.trim(), latitude: String(latitude), longitude: String(longitude) })}`,
    ),
  upload: async (id: number, uri: string, context: boolean) => {
    const { File } =
      // eslint-disable-next-line @typescript-eslint/no-require-imports -- Defer native file initialization until an explicit upload.
      require('expo-file-system') as typeof import('expo-file-system');
    const form = new FormData();
    form.append('image', new File(uri));
    return write<Inspection>(
      `${idPath('/inspections', id)}/${context ? 'context-image' : 'image'}`,
      form,
      'POST',
      90_000,
    );
  },
  analyze: (id: number, region: '' | 'FRONT' | 'REAR', signal?: AbortSignal) =>
    api.request<Inspection>(
      `${idPath('/inspections', id)}/analyze?requireContext=true${region ? `&vehicleRegion=${region}` : ''}`,
      { method: 'POST', timeout: 120_000, signal },
    ),
  quality: (id: number, context = false) =>
    write<Record<string, unknown>>(
      `${idPath('/inspections', id)}/${context ? 'context-image-quality' : 'image-quality'}`,
      undefined,
      'POST',
      120_000,
    ),
  checkPhotos: async (id: number) => {
    // Both endpoints share one reservation and the AI service has capacity=1.
    const general = await inspections.quality(id, true);
    const detail = await inspections.quality(id);
    return [general, detail] as const;
  },
  report: (id: number) =>
    write<Inspection>(
      `${idPath('/inspections', id)}/report`,
      undefined,
      'POST',
      120_000,
    ),
  nearby: (id: number, signal?: AbortSignal) =>
    getList<NearbyService>(
      `${idPath('/inspections', id)}/nearby-services`,
      signal,
    ),
  record: async (id: number, signal?: AbortSignal) => {
    try {
      return await get<DamageRecord>(
        `${idPath('/inspections', id)}/damage-record`,
        signal,
      );
    } catch (error) {
      if (error instanceof ApiError && error.status === 404) return null;
      throw error;
    }
  },
  saveRecord: (id: number, body: RecordInput, existing: boolean) =>
    write<DamageRecord>(
      `${idPath('/inspections', id)}/damage-record`,
      body,
      existing ? 'PUT' : 'POST',
    ),
  finalize: (id: number) =>
    write<DamageRecord>(`${idPath('/inspections', id)}/damage-record/finalize`),
};
export const business = {
  members: (signal?: AbortSignal) =>
    getList<BusinessMember>('/business-members', signal),
  create: async (companyName: string) => {
    await api.request('/business-accounts', {
      method: 'POST',
      body: { companyName: companyName.trim() },
    });
    await refreshProfile();
  },
  invite: (email: string) =>
    api.request('/business-invitations', {
      method: 'POST',
      body: { email: email.trim().toLowerCase() },
    }),
  accept: async (code: string) => {
    await api.request('/business-invitations/accept', {
      method: 'POST',
      body: { code: code.trim() },
    });
    await refreshProfile();
  },
  remove: async (id: number) => {
    await api.request(idPath('/business-members', id), { method: 'DELETE' });
    await refreshProfile();
  },
};
export const notifications = {
  list: (signal?: AbortSignal) =>
    getList<AppNotification>('/notifications?unreadOnly=false', signal),
  unread: (signal?: AbortSignal) =>
    get<{ unreadCount: number }>('/notifications/unread-count', signal),
  read: (id: number) =>
    write<AppNotification>(`${idPath('/notifications', id)}/read`, {}, 'PUT'),
  readAll: () =>
    api.request('/notifications/read-all', { method: 'PUT', body: {} }),
};
export const billingApi = {
  overview: () => get<BillingOverview>('/billing'),
  sync: () => write<BillingOverview>('/billing/sync'),
  credits: (signal?: AbortSignal) => get<CreditOverview>('/credits', signal),
};
export const assistantEntitlement = (signal?: AbortSignal) =>
  get<AssistantEntitlement>('/ai-assistant/entitlement', signal);
