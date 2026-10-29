import { isRecord, type Workspace } from './contracts';
import { Session, StaleSessionError } from './session';

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public code?: string,
  ) {
    super(message);
  }
}

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: unknown;
  auth?: boolean;
  workspace?: Workspace;
  timeout?: number;
  signal?: AbortSignal;
}

/** No automatic retries: mutations may consume credits or start paid analysis. */
export class Api {
  constructor(
    private baseUrl: string,
    private session: Session,
    private transport: typeof fetch = fetch,
  ) {
    const url = new URL(baseUrl);
    if (
      !['http:', 'https:'].includes(url.protocol) ||
      url.username ||
      url.password ||
      url.search ||
      url.hash
    ) {
      throw new Error('API adresi geçersiz.');
    }
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }
  async request<T = unknown>(
    path: string,
    options: RequestOptions = {},
  ): Promise<T> {
    if (
      !path.startsWith('/') ||
      path.startsWith('//') ||
      path.includes('://') ||
      path.includes('\\')
    ) {
      throw new Error('API yolu geçersiz.');
    }
    const snapshot = this.session.getSnapshot();
    const auth = options.auth !== false;
    const workspace = options.workspace ?? snapshot.workspace;
    const controller = new AbortController();
    const untrack = this.session.track(controller);
    const abort = () => controller.abort();
    options.signal?.addEventListener('abort', abort, { once: true });
    if (options.signal?.aborted) controller.abort();
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, options.timeout ?? 30_000);
    try {
      const multipart =
        typeof FormData !== 'undefined' && options.body instanceof FormData;
      const response = await this.transport(`${this.baseUrl}${path}`, {
        method: options.method ?? 'GET',
        headers: {
          Accept: 'application/json',
          ...(!multipart ? { 'Content-Type': 'application/json' } : {}),
          ...(auth ? { 'X-Workspace': workspace } : {}),
          ...(auth && snapshot.token
            ? { Authorization: `Bearer ${snapshot.token}` }
            : {}),
        },
        ...(options.body !== undefined
          ? {
              body: multipart
                ? (options.body as FormData)
                : JSON.stringify(options.body),
            }
          : {}),
        signal: controller.signal,
      });
      this.session.check(snapshot.generation);
      const raw = await response.text();
      this.session.check(snapshot.generation);
      let body: unknown;
      try {
        body = raw ? (JSON.parse(raw) as unknown) : undefined;
      } catch {
        body = undefined;
      }
      if (!response.ok) {
        const errors =
          isRecord(body) && isRecord(body.validationErrors)
            ? body.validationErrors
            : undefined;
        const code = typeof errors?.code === 'string' ? errors.code : undefined;
        if (
          auth &&
          response.status === 403 &&
          workspace === 'BUSINESS' &&
          code === 'WORKSPACE_UNAVAILABLE'
        ) {
          this.session.revokeBusiness();
        }
        if (auth && response.status === 401) {
          if (snapshot.token !== this.session.getSnapshot().token)
            throw new StaleSessionError();
          await this.session.logout();
        }
        const message = isRecord(body)
          ? (body.message ?? body.detail ?? body.error)
          : undefined;
        throw new ApiError(
          response.status,
          typeof message === 'string'
            ? message
            : response.status === 401
              ? 'Oturumunuz sona erdi. Lütfen tekrar giriş yapın.'
              : 'Sunucu işlemi tamamlayamadı.',
          code,
        );
      }
      const identity =
        path.startsWith('/auth/') ||
        path.startsWith('/app/') ||
        path === '/health';
      if (
        auth &&
        !identity &&
        response.headers.get('x-workspace') !== workspace
      ) {
        throw new ApiError(
          503,
          'Sunucu seçilen çalışma alanını doğrulamadı. Lütfen daha sonra tekrar deneyin.',
        );
      }
      if (path === '/auth/change-password') {
        const authorization = response.headers.get('authorization');
        if (
          authorization?.startsWith('Bearer ') &&
          authorization.slice(7).trim()
        ) {
          await this.session.rotateToken(
            authorization.slice(7),
            snapshot.generation,
          );
        } else {
          // Older servers revoke tokens without providing a replacement.
          await this.session.logout();
        }
      }
      if (raw && body === undefined)
        throw new ApiError(502, 'Sunucudan geçersiz yanıt alındı.');
      return body as T;
    } catch (error) {
      if (!(error instanceof ApiError)) this.session.check(snapshot.generation);
      if (timedOut)
        throw new ApiError(408, 'Sunucu yanıt vermedi. Lütfen tekrar deneyin.');
      if (error instanceof TypeError)
        throw new ApiError(
          0,
          'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
        );
      throw error;
    } finally {
      clearTimeout(timer);
      options.signal?.removeEventListener('abort', abort);
      untrack();
    }
  }
}
