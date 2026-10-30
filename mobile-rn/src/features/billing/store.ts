import { Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';
import type { PurchasesPackage } from 'react-native-purchases';
import { api, session } from '../../core/runtime';
import {
  BillingService,
  PaymentCancelled,
  PaymentPending,
  type StoreGateway,
  type PendingCredit,
} from './BillingService';

// Native module is loaded only when the purchase center opens, never for login.
const sdk = () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports -- Native store starts only after an explicit billing action.
  require('react-native-purchases') as typeof import('react-native-purchases');
const gateway: StoreGateway = {
  transactions: async () =>
    (await sdk().default.getCustomerInfo()).nonSubscriptionTransactions.map(
      (tx) => ({
        productId: tx.productIdentifier,
        id: tx.transactionIdentifier,
        date: tx.purchaseDate,
      }),
    ),
  configure: async (identity) => {
    if (!identity.trim()) throw new Error('Satın alma hesabı doğrulanamadı.');
    const key =
      Platform.OS === 'android'
        ? process.env.EXPO_PUBLIC_REVENUECAT_ANDROID_PUBLIC_KEY
        : process.env.EXPO_PUBLIC_REVENUECAT_IOS_PUBLIC_KEY;
    if (!key) return false;
    const Purchases = sdk().default;
    if (!(await Purchases.isConfigured()))
      Purchases.configure({ apiKey: key, appUserID: identity });
    else if ((await Purchases.getAppUserID()) !== identity)
      await Purchases.logIn(identity);
    if ((await Purchases.getAppUserID()) !== identity)
      throw new Error('Satın alma hesabı doğrulanamadı.');
    return true;
  },
  packages: async () => {
    const offerings = await sdk().default.getOfferings();
    return (
      (offerings.all.credits_v1 ?? offerings.current)?.availablePackages ?? []
    ).map((pkg) => ({
      identifier: pkg.identifier,
      storeProduct: pkg.product,
      native: pkg,
    }));
  },
  active: async (sku) =>
    (await sdk().default.getCustomerInfo()).activeSubscriptions.some(
      (id) => id === sku || id.startsWith(`${sku}:`),
    ),
  purchase: async (pkg, oldSku, upgrade) => {
    try {
      if (!pkg.native) throw new Error('Mağaza paketi doğrulanamadı.');
      const module = sdk();
      const result = await module.default.purchasePackage(
        pkg.native as PurchasesPackage,
        null,
        Platform.OS === 'android' && oldSku
          ? {
              oldProductIdentifier: oldSku,
              replacementMode: upgrade
                ? module.STORE_REPLACEMENT_MODE.WITH_TIME_PRORATION
                : module.STORE_REPLACEMENT_MODE.DEFERRED,
            }
          : null,
      );
      if (!result.transaction?.transactionIdentifier)
        throw new PaymentPending();
      return result.transaction.transactionIdentifier;
    } catch (error) {
      const code =
        error && typeof error === 'object' && 'code' in error
          ? String(error.code)
          : '';
      if (code === sdk().PURCHASES_ERROR_CODE.PURCHASE_CANCELLED_ERROR)
        throw new PaymentCancelled();
      if (code === sdk().PURCHASES_ERROR_CODE.PAYMENT_PENDING_ERROR)
        throw new PaymentPending();
      throw error;
    }
  },
  restore: async () => {
    await sdk().default.restorePurchases();
  },
};
export const billing = new BillingService(api, session, gateway, {
  read: async (scope) => {
    const state = session.getSnapshot();
    const legacyKey = `pending-credit.${state.profile!.id}.${state.workspace}.${state.workspace === 'BUSINESS' ? (state.profile!.businessAccount?.id ?? 0) : 'personal'}`;
    const key = `pending-credit.${scope}`;
    // Preserve journals created by the migration client; copy before deleting.
    const legacy = await SecureStore.getItemAsync(legacyKey);
    const current = await SecureStore.getItemAsync(key);
    const raw = legacy
      ? JSON.stringify([
          ...(current ? JSON.parse(current) : []),
          ...JSON.parse(legacy),
        ])
      : current;
    if (!raw) return [];
    const value: unknown = JSON.parse(raw);
    if (
      !Array.isArray(value) ||
      !value.every(
        (item) =>
          item &&
          typeof item.sku === 'string' &&
          Number.isFinite(item.at) &&
          Array.isArray(item.known) &&
          item.known.every((id: unknown) => typeof id === 'string') &&
          (item.transaction == null || typeof item.transaction === 'string') &&
          (item.kind == null ||
            (item.kind === 'subscription' && typeof item.plan === 'string')),
      )
    )
      throw new Error(
        'Bekleyen satın alma kaydı okunamadı. Tekrar ödeme yapmadan destek alın.',
      );
    if (legacy) {
      await SecureStore.setItemAsync(key, JSON.stringify(value));
      await SecureStore.deleteItemAsync(legacyKey);
    }
    return value as PendingCredit[];
  },
  write: (scope, items) =>
    SecureStore.setItemAsync(`pending-credit.${scope}`, JSON.stringify(items)),
});
