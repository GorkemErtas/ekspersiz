import type { UserProfile, Workspace } from './contracts';

export interface SessionState {
  ready: boolean;
  token: string | null;
  profile: UserProfile | null;
  workspace: Workspace;
  generation: number;
}

export class StaleSessionError extends Error {
  constructor() {
    super(
      'Çalışma alanı veya oturum değişti. İşlemi seçili alanda yeniden açın.',
    );
  }
}

export interface SessionStorage {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
  remove(key: string): Promise<void>;
}

/** One native credential queue: old writes cannot finish after logout/new login. */
export class Session {
  private state: SessionState = {
    ready: false,
    token: null,
    profile: null,
    workspace: 'PERSONAL',
    generation: 0,
  };
  private listeners = new Set<() => void>();
  private controllers = new Set<AbortController>();
  private writes: Promise<void> = Promise.resolve();
  private profileRequest = 0;
  constructor(
    private storage: SessionStorage,
    private clearProtectedData: () => void,
  ) {}

  getSnapshot = (): SessionState => this.state;
  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };
  check(generation: number): void {
    if (this.state.generation !== generation) throw new StaleSessionError();
  }
  track(controller: AbortController): () => void {
    this.controllers.add(controller);
    return () => this.controllers.delete(controller);
  }
  private publish(next: Partial<SessionState>, boundary = false): void {
    if (boundary) {
      for (const controller of this.controllers) controller.abort();
      this.controllers.clear();
      this.profileRequest++;
      this.clearProtectedData();
    }
    this.state = {
      ...this.state,
      ...next,
      generation: this.state.generation + (boundary ? 1 : 0),
    };
    for (const listener of this.listeners) listener();
  }
  private write(action: () => Promise<void>): Promise<void> {
    const next = this.writes.then(action);
    this.writes = next.catch(() => undefined);
    return next;
  }
  async restore(): Promise<void> {
    const generation = this.state.generation;
    const token = await this.storage.get('access_token');
    this.check(generation);
    this.publish({ token, ready: true });
  }
  beginLogin(): number {
    this.publish(
      { token: null, profile: null, workspace: 'PERSONAL', ready: true },
      true,
    );
    // Queue synchronously; a later successful login writes after this removal.
    void this.write(() => this.storage.remove('access_token')).catch(
      () => undefined,
    );
    return this.state.generation;
  }
  async authenticate(
    token: string,
    profile: UserProfile,
    generation: number,
  ): Promise<void> {
    this.check(generation);
    if (!token.trim())
      throw new Error('Sunucudan geçerli bir erişim anahtarı alınamadı.');
    await this.write(() => this.storage.set('access_token', token));
    this.check(generation);
    const preference = await this.storage
      .get(`workspace.user.${profile.id}`)
      .catch(() => null);
    this.check(generation);
    const workspace =
      preference !== 'PERSONAL' && profile.businessAccount?.workspaceAvailable
        ? 'BUSINESS'
        : 'PERSONAL';
    this.publish({ token, profile, workspace }, true);
  }
  async logout(): Promise<void> {
    this.publish(
      { token: null, profile: null, workspace: 'PERSONAL', ready: true },
      true,
    );
    await this.write(() => this.storage.remove('access_token'));
  }
  async rotateToken(token: string, generation: number): Promise<void> {
    this.check(generation);
    await this.write(() => this.storage.set('access_token', token));
    this.check(generation);
    this.publish({ token });
  }
  async refreshProfile(load: () => Promise<UserProfile>): Promise<void> {
    const request = ++this.profileRequest;
    const generation = this.state.generation;
    const profile = await load();
    this.check(generation);
    if (request !== this.profileRequest) throw new StaleSessionError();
    if (this.state.profile && profile.id !== this.state.profile.id)
      throw new Error('Kullanıcı kimliği değişti.');
    const previous = this.state.profile?.businessAccount;
    const business = profile.businessAccount;
    const workspace =
      business?.workspaceAvailable &&
      (previous === undefined ||
        previous === null ||
        previous.id === business.id)
        ? this.state.workspace
        : 'PERSONAL';
    // Plan-only changes must not cancel a purchase that is reconciling.
    const boundary =
      workspace !== this.state.workspace ||
      previous?.id !== business?.id ||
      previous?.companyName !== business?.companyName ||
      previous?.role !== business?.role ||
      previous?.workspaceAvailable !== business?.workspaceAvailable ||
      previous?.workspaceAccessStatus !== business?.workspaceAccessStatus ||
      previous?.sandbox !== business?.sandbox;
    this.publish({ profile, workspace }, boundary);
  }
  async select(
    workspace: Workspace,
    authorize: () => Promise<unknown>,
  ): Promise<void> {
    const current = this.state;
    if (
      !current.profile ||
      (workspace === 'BUSINESS' &&
        !current.profile.businessAccount?.workspaceAvailable)
    ) {
      throw new Error('Şirket çalışma alanı kullanılamıyor.');
    }
    const result = await authorize();
    this.check(current.generation);
    const expectedBusiness =
      workspace === 'BUSINESS' ? current.profile.businessAccount?.id : null;
    if (
      !result ||
      typeof result !== 'object' ||
      !('type' in result) ||
      result.type !== workspace ||
      !('userId' in result) ||
      result.userId !== current.profile.id ||
      !('businessId' in result) ||
      result.businessId !== expectedBusiness
    ) {
      throw new Error('Çalışma alanı bilgileri değişti. Hesabınızı yenileyin.');
    }
    if (workspace === current.workspace) return;
    this.publish({ workspace }, true);
    const generation = this.state.generation;
    await this.write(() =>
      this.storage.set(`workspace.user.${current.profile!.id}`, workspace),
    ).catch(() => undefined);
    this.check(generation);
  }
  revokeBusiness(): void {
    const profile = this.state.profile;
    this.publish(
      {
        workspace: 'PERSONAL',
        profile: profile
          ? {
              ...profile,
              businessAccount: profile.businessAccount
                ? {
                    ...profile.businessAccount,
                    workspaceAvailable: false,
                    workspaceAccessStatus: 'UNKNOWN',
                  }
                : null,
            }
          : null,
      },
      true,
    );
    if (profile)
      void this.write(() =>
        this.storage.set(`workspace.user.${profile.id}`, 'PERSONAL'),
      ).catch(() => undefined);
  }
}
