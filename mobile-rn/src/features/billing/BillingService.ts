import type { Api } from '../../core/api';
import type { Session } from '../../core/session';
import type {
  BillingOverview,
  BillingPlan,
  CreditOverview,
  CreditProduct,
} from '../../core/models';

export interface StorePackage {
  identifier: string;
  storeProduct: {
    identifier: string;
    price: number;
    currencyCode: string;
    priceString: string;
  };
  native?: unknown;
}
export interface StoreGateway {
  transactions?: () => Promise<
    { productId: string; id: string; date: string }[]
  >;
  configure: (identity: string) => Promise<boolean>;
  packages: () => Promise<StorePackage[]>;
  active: (sku: string) => Promise<boolean>;
  purchase: (
    pkg: StorePackage,
    oldSku?: string,
    upgrade?: boolean,
  ) => Promise<string>;
  restore: () => Promise<void>;
}
export interface PendingCredit {
  sku: string;
  at: number;
  known: string[];
  transaction?: string;
  kind?: 'subscription';
  plan?: string;
}
export interface PendingStore {
  read: (scope: string) => Promise<PendingCredit[]>;
  write: (scope: string, items: PendingCredit[]) => Promise<void>;
}
export class PaymentCancelled extends Error {
  constructor() {
    super('Satın alma iptal edildi.');
  }
}
export class PaymentPending extends Error {
  constructor() {
    super(
      'Satın alma mağazada alındı veya bekliyor. Ödeme tekrarlanmadan sunucu onayı kontrol edilmelidir.',
    );
  }
}
/** Single native store identity/sheet at a time, including user/workspace changes. */
export class BillingService {
  private busy = false;
  private pending = new Map<string, PendingCredit[]>();
  get isBusy() {
    return this.busy;
  }
  private scope() {
    const state = this.session.getSnapshot();
    if (!state.profile) throw new Error('Önce giriş yapın.');
    // RevenueCat identity belongs to the user. A workspace/company change must
    // not bypass an unresolved payment or replace its server purchase intent.
    return `user.${state.profile.id}`;
  }
  isPending(sku: string) {
    return (
      !!this.session.getSnapshot().profile &&
      (this.pending.get(this.scope()) ?? []).some((item) => item.sku === sku)
    );
  }
  private async readPending(scope: string) {
    const items =
      (await this.pendingStore?.read(scope)) ?? this.pending.get(scope) ?? [];
    this.pending.set(scope, items);
    return items;
  }
  private async savePending(scope: string, items: PendingCredit[]) {
    await this.pendingStore?.write(scope, items);
    this.pending.set(scope, items);
  }
  constructor(
    private api: Api,
    private session: Session,
    private gateway: StoreGateway,
    private pendingStore?: PendingStore,
  ) {}
  private async exclusive<T>(action: () => Promise<T>): Promise<T> {
    if (this.busy) throw new Error('Başka bir satın alma işlemi devam ediyor.');
    this.busy = true;
    try {
      return await action();
    } finally {
      this.busy = false;
    }
  }
  private overview = () => this.api.request<BillingOverview>('/billing');
  private sync = () =>
    this.api.request<BillingOverview>('/billing/sync', { method: 'POST' });
  private check = (generation: number) => this.session.check(generation);
  async load() {
    return this.exclusive(async () => {
      const { generation } = this.session.getSnapshot();
      const scope = this.scope();
      await this.readPending(scope);
      this.check(generation);
      const overview = await this.overview();
      this.check(generation);
      const configured = await this.gateway.configure(
        overview.status.billingCustomerId,
      );
      this.check(generation);
      if (!configured)
        return { overview, packages: [] as StorePackage[], configured: false };
      const verified = await this.sync();
      this.check(generation);
      // One explicit reconciliation per page refresh. Unknown/pending payments never open another sheet.
      const pending = await this.readPending(scope);
      this.check(generation);
      if (pending.length) {
        const transactions = (await this.gateway.transactions?.()) ?? [];
        this.check(generation);
        for (const item of pending) {
          this.check(generation);
          if (item.kind === 'subscription') {
            if (verified.status.currentPlan === item.plan)
              await this.savePending(
                scope,
                (this.pending.get(scope) ?? []).filter(
                  (entry) => entry !== item,
                ),
              );
            continue;
          }
          const transaction =
            item.transaction ??
            transactions.find(
              (tx) =>
                tx.productId === item.sku &&
                !item.known.includes(tx.id) &&
                Date.parse(tx.date) >= item.at - 1000,
            )?.id;
          if (!transaction) continue;
          try {
            const result = await this.api.request<{ confirmed: boolean }>(
              `/credits/purchases/${encodeURIComponent(transaction)}`,
            );
            this.check(generation);
            if (result.confirmed === true)
              await this.savePending(
                scope,
                (this.pending.get(scope) ?? []).filter(
                  (entry) => entry !== item,
                ),
              );
          } catch {
            this.check(generation);
          }
        }
      }
      this.check(generation);
      let packages: StorePackage[] = [];
      try {
        packages = await this.gateway.packages();
      } catch {
        /* Backend-verified access remains visible during store outages. */
      }
      this.check(generation);
      return { overview: verified, packages, configured };
    });
  }
  async purchaseCredit(product: CreditProduct) {
    return this.exclusive(async () => {
      const { generation, workspace } = this.session.getSnapshot();
      const scope = this.scope(),
        pending = await this.readPending(scope);
      this.check(generation);
      if (pending.some((item) => item.sku === product.productId))
        throw new PaymentPending();
      const credits = await this.api.request<CreditOverview>('/credits');
      this.check(generation);
      const account =
        workspace === 'BUSINESS' ? credits.company : credits.personal;
      if (
        !account?.canPurchase ||
        (workspace === 'BUSINESS' && !account.owner) ||
        product.business !== (workspace === 'BUSINESS')
      )
        throw new Error('Seçili çalışma alanında satın alma yetkiniz yok.');
      const canonical = credits.products.find(
        (item) =>
          item.productId === product.productId &&
          item.business === product.business,
      );
      if (!canonical) throw new Error('Paket artık kullanılamıyor.');
      const overview = await this.overview();
      this.check(generation);
      if (!(await this.gateway.configure(overview.status.billingCustomerId)))
        throw new Error('Satın alma mağazası şu anda kullanılamıyor.');
      this.check(generation);
      const packages = await this.gateway.packages();
      this.check(generation);
      const pkg = indexPackages(packages).get(product.productId);
      if (!pkg || pkg.storeProduct.identifier !== product.productId)
        throw new Error('Bu paket mağazada henüz yayınlanmadı.');
      const known = ((await this.gateway.transactions?.()) ?? [])
        .filter(
          (tx) =>
            tx.productId === product.productId &&
            Date.parse(tx.date) >= Date.now() - 10_000,
        )
        .map((tx) => tx.id);
      this.check(generation);
      const item: PendingCredit = {
        sku: product.productId,
        at: Date.now(),
        known,
      };
      await this.savePending(scope, [...pending, item]);
      try {
        this.check(generation);
        await this.api.request(
          `/credits/purchase-intents/${encodeURIComponent(product.productId)}`,
          { method: 'POST' },
        );
        this.check(generation);
      } catch (error) {
        // No native sheet was opened, so removing this marker cannot hide a payment.
        await this.savePending(scope, pending);
        throw error;
      }
      let transaction: string;
      try {
        transaction = await this.gateway.purchase(pkg);
        item.transaction = transaction;
        await this.savePending(scope, [...pending, item]);
      } catch (error) {
        if (error instanceof PaymentCancelled) {
          await this.savePending(scope, pending);
          throw error;
        }
        throw new PaymentPending();
      }
      try {
        this.check(generation);
        await this.sync();
        this.check(generation);
        const result = await this.api.request<{ confirmed: boolean }>(
          `/credits/purchases/${encodeURIComponent(transaction)}`,
        );
        this.check(generation);
        if (result.confirmed !== true) throw new PaymentPending();
        await this.savePending(scope, pending);
        return true;
      } catch {
        throw new PaymentPending();
      }
    });
  }
  async purchasePlan(plan: BillingPlan) {
    return this.exclusive(async () => {
      const { generation, profile } = this.session.getSnapshot();
      const scope = this.scope(),
        pending = await this.readPending(scope);
      this.check(generation);
      if (
        plan.plan === 'BUSINESS' &&
        profile?.businessAccount &&
        profile.businessAccount.role !== 'OWNER'
      )
        throw new Error('Business satın alma işlemini şirket sahibi yönetir.');
      const overview = await this.overview();
      this.check(generation);
      if (!(await this.gateway.configure(overview.status.billingCustomerId)))
        throw new Error('Satın alma mağazası şu anda kullanılamıyor.');
      this.check(generation);
      const verified = await this.sync();
      this.check(generation);
      if (
        verified.status.currentPlan === plan.plan ||
        verified.status.verificationStatus === 'SANDBOX_REJECTED'
      )
        return verified;
      const canonical = verified.plans.find((item) => item.plan === plan.plan);
      if (!canonical?.productId || !canonical.packageIdentifier)
        throw new Error('Bu plan mağaza üzerinden satın alınamaz.');
      if (await this.gateway.active(canonical.productId)) {
        this.check(generation);
        throw new PaymentPending();
      }
      this.check(generation);
      if (pending.some((item) => item.sku === canonical.productId))
        throw new PaymentPending();
      const packages = await this.gateway.packages();
      this.check(generation);
      const pkg = indexPackages(packages).get(canonical.packageIdentifier);
      if (
        !pkg ||
        !(
          pkg.storeProduct.identifier === canonical.productId ||
          pkg.storeProduct.identifier.startsWith(`${canonical.productId}:`)
        )
      )
        throw new Error('Bu plan mağazada henüz yayınlanmadı.');
      const changing =
        verified.status.currentPlan !== 'FREE' &&
        verified.status.currentPlan !== canonical.plan;
      const rank = (value: string) =>
        ['FREE', 'PLUS', 'PRO', 'BUSINESS'].indexOf(value);
      if (changing && !verified.status.productId)
        throw new Error(
          'Mevcut mağaza aboneliği doğrulanamadı. Yeniden ödeme yapmadan aboneliği kontrol edin.',
        );
      const item: PendingCredit = {
        sku: canonical.productId,
        at: Date.now(),
        known: [],
        kind: 'subscription',
        plan: canonical.plan,
      };
      await this.savePending(scope, [...pending, item]);
      try {
        this.check(generation);
      } catch (error) {
        await this.savePending(scope, pending);
        throw error;
      }
      try {
        item.transaction = await this.gateway.purchase(
          pkg,
          changing ? verified.status.productId! : undefined,
          rank(canonical.plan) > rank(verified.status.currentPlan),
        );
        await this.savePending(scope, [...pending, item]);
      } catch (error) {
        if (error instanceof PaymentCancelled) {
          await this.savePending(scope, pending);
          throw error;
        }
        throw new PaymentPending();
      }
      try {
        this.check(generation);
        const result = await this.sync();
        this.check(generation);
        if (result.status.currentPlan !== canonical.plan)
          throw new PaymentPending();
        await this.savePending(scope, pending);
        return result;
      } catch {
        throw new PaymentPending();
      }
    });
  }
  async restore() {
    return this.exclusive(async () => {
      const { generation } = this.session.getSnapshot();
      const overview = await this.overview();
      this.check(generation);
      if (!(await this.gateway.configure(overview.status.billingCustomerId)))
        throw new Error('Satın alma mağazası şu anda kullanılamıyor.');
      this.check(generation);
      await this.gateway.restore();
      this.check(generation);
      return this.sync();
    });
  }
}
export function indexPackages(packages: StorePackage[]) {
  const map = new Map(packages.map((pkg) => [pkg.identifier, pkg]));
  for (const pkg of packages) map.set(pkg.storeProduct.identifier, pkg);
  return map;
}
