import { Session } from '../../core/session';
import type { Api } from '../../core/api';
import type { BillingOverview, CreditProduct } from '../../core/models';
import {
  BillingService,
  indexPackages,
  PaymentCancelled,
  PaymentPending,
  type PendingCredit,
  type StoreGateway,
} from './BillingService';
const product: CreditProduct = {
  productId: 'analysis_10',
  quantity: 10,
  business: false,
  resource: 'ANALYSIS',
  referencePrice: 100,
};
const overview: BillingOverview = {
  status: {
    billingCustomerId: 'server_identity_7',
    currentPlan: 'FREE',
    status: 'ACTIVE',
    autoRenewing: false,
    sandbox: false,
    verificationStatus: 'VERIFIED',
  },
  plans: [
    {
      plan: 'BUSINESS',
      title: 'Business',
      description: '',
      productId: 'business',
      packageIdentifier: 'business_monthly',
      fallbackMonthlyPrice: 100,
      currency: 'TRY',
      highlighted: true,
      features: [],
    },
  ],
};
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
    'token',
    {
      id: 7,
      fullName: 'Deniz',
      email: 'deniz@example.com',
      subscriptionPlan: 'FREE',
      businessAccount: null,
    },
    session.beginLogin(),
  );
  const order: string[] = [],
    request = jest.fn(async (path: string): Promise<unknown> => {
      order.push(path);
      if (path === '/credits')
        return {
          personal: { canPurchase: true, owner: true },
          company: null,
          products: [product],
        };
      if (path.startsWith('/credits/purchases/')) return { confirmed: true };
      if (path.includes('purchase-intents')) return undefined;
      return overview;
    });
  const gateway: StoreGateway = {
    configure: jest.fn(async () => true),
    packages: jest.fn(async () => [
      {
        identifier: 'alias',
        storeProduct: {
          identifier: product.productId,
          price: 100,
          currencyCode: 'TRY',
          priceString: '₺100',
        },
      },
    ]),
    active: jest.fn(async () => false),
    purchase: jest.fn(async () => {
      order.push('native');
      return 'GPA.txn/1';
    }),
    restore: jest.fn(async () => undefined),
    transactions: jest.fn(async () => []),
  };
  let stored: PendingCredit[] = [];
  const pendingStore = {
    read: jest.fn(async () => stored),
    write: jest.fn(async (_: string, items: PendingCredit[]) => {
      stored = JSON.parse(JSON.stringify(items));
    }),
  };
  return {
    session,
    gateway,
    request,
    order,
    pendingStore,
    service: new BillingService(
      { request } as unknown as Api,
      session,
      gateway,
      pendingStore,
    ),
  };
}
test('credit intent precedes payment; only server-confirmed transactions grant success', async () => {
  const x = await setup();
  await expect(x.service.purchaseCredit(product)).resolves.toBe(true);
  expect(x.order).toEqual([
    '/credits',
    '/billing',
    '/credits/purchase-intents/analysis_10',
    'native',
    '/billing/sync',
    '/credits/purchases/GPA.txn%2F1',
  ]);
  expect(x.gateway.configure).toHaveBeenCalledWith('server_identity_7');
  expect(x.service.isPending(product.productId)).toBe(false);
});
test('pending confirmation persists across screen/service recreation and cannot charge again', async () => {
  const x = await setup();
  x.request.mockImplementation(async (path) =>
    path === '/credits'
      ? { personal: { canPurchase: true, owner: true }, products: [product] }
      : path.startsWith('/credits/purchases/')
        ? { confirmed: false }
        : overview,
  );
  await expect(x.service.purchaseCredit(product)).rejects.toBeInstanceOf(
    PaymentPending,
  );
  const next = new BillingService(
    { request: x.request } as unknown as Api,
    x.session,
    x.gateway,
    x.pendingStore,
  );
  await expect(next.purchaseCredit(product)).rejects.toBeInstanceOf(
    PaymentPending,
  );
  expect(x.gateway.purchase).toHaveBeenCalledTimes(1);
  await next.load();
  expect(next.isPending(product.productId)).toBe(true);
});
test('explicit reconciliation clears a confirmed pending transaction without another purchase', async () => {
  const x = await setup();
  (x.gateway.purchase as jest.Mock).mockRejectedValueOnce(new PaymentPending());
  await expect(x.service.purchaseCredit(product)).rejects.toBeInstanceOf(
    PaymentPending,
  );
  (x.gateway.transactions as jest.Mock).mockResolvedValue([
    {
      productId: product.productId,
      id: 'later-txn',
      date: new Date().toISOString(),
    },
  ]);
  await x.service.load();
  expect(x.service.isPending(product.productId)).toBe(false);
  expect(x.gateway.purchase).toHaveBeenCalledTimes(1);
});
test('cancelled payments remove the pending marker and never reconcile or grant credits', async () => {
  const x = await setup();
  (x.gateway.purchase as jest.Mock).mockRejectedValueOnce(
    new PaymentCancelled(),
  );
  await expect(x.service.purchaseCredit(product)).rejects.toBeInstanceOf(
    PaymentCancelled,
  );
  expect(x.service.isPending(product.productId)).toBe(false);
  expect(x.order).not.toContain('/billing/sync');
});
test('single native sheet lock survives user changes; late success never reconciles as the next user', async () => {
  const x = await setup();
  let finish!: (id: string) => void;
  (x.gateway.purchase as jest.Mock).mockImplementation(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  const first = x.service.purchaseCredit(product);
  while (!finish) await Promise.resolve();
  await expect(x.service.purchaseCredit(product)).rejects.toThrow(
    'devam ediyor',
  );
  await x.session.logout();
  finish('old-user-txn');
  await expect(first).rejects.toBeInstanceOf(PaymentPending);
  expect(x.order).not.toContain('/billing/sync');
});
test('native package aliases cannot replace an actual SKU mapping', () => {
  const real = {
      identifier: 'alias',
      storeProduct: {
        identifier: 'real',
        price: 1,
        currencyCode: 'TRY',
        priceString: '1',
      },
    },
    collision = {
      identifier: 'real',
      storeProduct: {
        identifier: 'different',
        price: 2,
        currencyCode: 'TRY',
        priceString: '2',
      },
    };
  expect(indexPackages([real, collision]).get('real')).toBe(real);
});
test('an already active store subscription suppresses a duplicate payment', async () => {
  const x = await setup();
  (x.gateway.active as jest.Mock).mockResolvedValue(true);
  await x.service.purchasePlan(overview.plans[0]!);
  expect(x.gateway.purchase).not.toHaveBeenCalled();
  expect(x.order.filter((path) => path === '/billing/sync')).toHaveLength(1);
});
