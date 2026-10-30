import { Linking, Platform, View } from 'react-native';
import { useRouter } from 'expo-router';
import { api, session, useSession } from '../../core/runtime';
import { billingApi, refreshProfile } from '../../core/services';
import { useResource, invalidate } from '../../core/queries';
import { dateText, label, money } from '../../core/labels';
import { welcomeCredits } from '../../platform/native';
import { AppText, Button, Card, Gap } from '../../design/components';
import { Badge, Heading, Page, Select, StateView } from '../../design/layout';
import { useAction } from '../auth/useAction';
import { billing } from './store';
import {
  indexPackages,
  PaymentCancelled,
  PaymentPending,
  type StorePackage,
} from './BillingService';
import { useState } from 'react';

export function savings(
  price: StorePackage['storeProduct'] | undefined,
  single: StorePackage['storeProduct'] | undefined,
  quantity: number,
) {
  if (
    !price ||
    !single ||
    price.currencyCode !== single.currencyCode ||
    !Number.isFinite(price.price) ||
    !Number.isFinite(single.price) ||
    price.price < 0 ||
    single.price <= 0 ||
    quantity <= 1
  )
    return null;
  const regular = single.price * quantity,
    amount = Math.round((regular - price.price) * 100) / 100;
  return amount > 0
    ? { amount, percent: (1 - price.price / regular) * 100 }
    : null;
}
export default function BillingScreen() {
  const router = useRouter(),
    { profile, workspace } = useSession(),
    action = useAction();
  const data = useResource('billing/store', () => billing.load()),
    credits = useResource('credits', billingApi.credits),
    [resource, setResource] = useState('ANALYSIS'),
    [notice, setNotice] = useState('');
  const account =
    workspace === 'BUSINESS' ? credits.data?.company : credits.data?.personal;
  const packages = indexPackages(data.data?.packages ?? []),
    status = data.data?.overview.status;
  const refresh = async () => {
    await data.refetch();
    await credits.refetch();
    await refreshProfile();
  };
  const perform = (task: () => Promise<string>) =>
    void action.run(async () => {
      try {
        const message = await task();
        setNotice(message);
        await refresh();
        action.show(message);
      } catch (error) {
        if (error instanceof PaymentCancelled) return;
        if (error instanceof PaymentPending) {
          setNotice(error.message);
          return;
        }
        throw error;
      }
    });
  const continueBusiness = async () => {
    await refreshProfile();
    const current = session.getSnapshot().profile;
    if (current?.subscriptionPlan !== 'BUSINESS')
      throw new Error(
        'Aktif Business aboneliği henüz sunucudan doğrulanmadı. Yeniden ödeme yapmadan kontrol edin.',
      );
    if (current.businessAccount?.workspaceAvailable) {
      await session.select('BUSINESS', () =>
        api.request('/workspace', { workspace: 'BUSINESS' }),
      );
    } else router.push('/business');
  };
  const manage = async () => {
    const url =
      status?.managementUrl ??
      (Platform.OS === 'ios'
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions');
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:')
      throw new Error('Abonelik yönetim bağlantısı geçersiz.');
    await Linking.openURL(url);
  };
  return (
    <Page
      title="Krediler ve Paketler"
      onRefresh={() => void action.run(refresh)}
      refreshing={action.busy}
    >
      <Heading
        title="İhtiyacınız kadar kullanın"
        description="Hasar analizi, AI Asistan ve araç slotlarını yönetin."
        icon="verified"
      />
      {data.isPending || data.error || credits.isPending || credits.error ? (
        <StateView
          loading={data.isPending || credits.isPending}
          error={data.error ?? credits.error}
          retry={() => void refresh()}
        />
      ) : (
        <>
          {notice && (
            <Card>
              <AppText accessibilityRole="alert">{notice}</AppText>
              <Button
                label="Yeniden kontrol et"
                variant="text"
                disabled={action.busy}
                onPress={() => void action.run(refresh)}
              />
            </Card>
          )}
          {status?.verificationStatus === 'SANDBOX_REJECTED' && (
            <Card>
              <AppText>
                Test mağazası satın alımı bu sunucuda üretim aboneliği olarak
                kabul edilmedi. Yeniden ödeme yapmadan yapılandırmayı kontrol
                edin.
              </AppText>
            </Card>
          )}
          <Card>
            <AppText variant="titleLarge">
              {workspace === 'BUSINESS'
                ? 'Şirket Bakiyesi'
                : 'Kişisel Bakiyeniz'}
            </AppText>
            <Gap />
            {account ? (
              <>
                <View
                  style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 12 }}
                >
                  {['ANALYSIS', 'ASSISTANT'].map((key) => (
                    <View key={key} style={{ flexGrow: 1 }}>
                      <AppText variant="headlineMedium">
                        {account.balances[key]?.available ?? 0}
                      </AppText>
                      <AppText>
                        {key === 'ANALYSIS'
                          ? 'Hasar analizi'
                          : 'Asistan kredisi'}
                      </AppText>
                      <AppText variant="bodySmall">
                        Dönem hakkı: {account.balances[key]?.periodic ?? 0}
                      </AppText>
                    </View>
                  ))}
                </View>
                <Gap />
                <AppText>
                  Araç slotları: {account.usedSlots} / {account.totalSlots}
                </AppText>
              </>
            ) : (
              <AppText>Bakiye alınamadı. Yeniden kontrol edin.</AppText>
            )}
          </Card>
          {status && ['PLUS', 'PRO'].includes(status.currentPlan) && (
            <Card>
              <Badge text={status.currentPlan} />
              <Gap />
              <AppText>
                Önceki aboneliğinizin ödenmiş dönem hakları korunur. Yeni
                bireysel alımlar kredi paketleriyle yapılır.
              </AppText>
              <Button
                label="Önceki aboneliği yönet / iptal et"
                variant="text"
                onPress={() => void action.run(manage)}
              />
            </Card>
          )}
          <Select
            title="Paket türü"
            value={resource}
            onChange={setResource}
            items={[
              { value: 'ANALYSIS', title: 'Hasar analizi' },
              { value: 'ASSISTANT', title: 'AI Asistan' },
              { value: 'SLOT', title: 'Araç slotları' },
            ]}
          />
          <AppText>
            {resource === 'SLOT'
              ? 'Ek slotlar kalıcıdır. Silinen aracın slotunu tekrar kullanabilirsiniz.'
              : 'Satın aldığınız krediler süresizdir. Her başarılı işlem 1 kredi kullanır.'}
          </AppText>
          {account && !account.canPurchase && (
            <AppText>
              {account.owner
                ? 'Şirket adına kredi alabilmek için Business aboneliğinizi yenileyin.'
                : 'Şirket adına satın alımları yalnızca şirket sahibi yapabilir.'}
            </AppText>
          )}
          {credits.data?.products
            .filter(
              (product) =>
                product.business === (workspace === 'BUSINESS') &&
                product.resource === resource,
            )
            .map((product) => {
              const price = packages.get(product.productId)?.storeProduct;
              const singleProduct = credits.data?.products.find(
                (item) =>
                  item.business === product.business &&
                  item.resource === resource &&
                  item.quantity === 1,
              );
              const saving = savings(
                price,
                singleProduct
                  ? packages.get(singleProduct.productId)?.storeProduct
                  : undefined,
                product.quantity,
              );
              return (
                <Card key={product.productId}>
                  <AppText variant="titleLarge">
                    {product.quantity}{' '}
                    {resource === 'SLOT'
                      ? 'Araç Slotu'
                      : resource === 'ASSISTANT'
                        ? 'Asistan Kredisi'
                        : 'Analiz Kredisi'}
                  </AppText>
                  <Gap />
                  <AppText variant="headlineSmall">
                    {price?.priceString ??
                      `${money(product.referencePrice, 'TRY')} (referans fiyat)`}
                  </AppText>
                  {price && (
                    <AppText variant="bodySmall">
                      Birim fiyat:{' '}
                      {money(
                        price.price / product.quantity,
                        price.currencyCode,
                      )}
                    </AppText>
                  )}
                  {saving && price && (
                    <AppText variant="bodySmall">
                      %
                      {saving.percent.toLocaleString('tr-TR', {
                        maximumFractionDigits: 2,
                      })}{' '}
                      avantaj • {money(saving.amount, price.currencyCode)}{' '}
                      tasarruf
                    </AppText>
                  )}
                  <Gap />
                  <Button
                    label={
                      billing.isPending(product.productId)
                        ? 'Mağaza onayı bekleniyor'
                        : price
                          ? 'Satın Al'
                          : 'Mağazada henüz yayınlanmadı'
                    }
                    disabled={
                      action.busy ||
                      billing.isPending(product.productId) ||
                      !price ||
                      !data.data?.configured ||
                      !account?.canPurchase
                    }
                    onPress={() =>
                      perform(async () => {
                        await billing.purchaseCredit(product);
                        await invalidate('credits');
                        return 'Satın alma doğrulandı. Bakiyeniz güncellendi.';
                      })
                    }
                  />
                </Card>
              );
            })}
          {profile?.businessAccount?.role !== 'MEMBER' &&
            data.data?.overview.plans
              .filter((plan) => plan.plan === 'BUSINESS')
              .map((plan) => {
                const pkg = plan.packageIdentifier
                  ? packages.get(plan.packageIdentifier)
                  : undefined;
                const active = status?.currentPlan === 'BUSINESS';
                return (
                  <Card key={plan.plan}>
                    <AppText variant="headlineSmall">
                      Business{status?.sandbox ? ' (Test aboneliği)' : ''}
                    </AppText>
                    <Gap />
                    <AppText>{plan.description}</AppText>
                    {plan.features.map((feature) => (
                      <AppText key={feature}>• {feature}</AppText>
                    ))}
                    <Gap />
                    <AppText variant="titleLarge">
                      {pkg?.storeProduct.priceString ??
                        `${money(plan.fallbackMonthlyPrice, plan.currency)} (referans fiyat)`}{' '}
                      / ay
                    </AppText>
                    {active ? (
                      <>
                        <Gap />
                        <Badge
                          text={
                            status.autoRenewing
                              ? 'Aktif abonelik'
                              : 'Dönem sonunda sona erer'
                          }
                        />
                        <AppText>
                          Dönem sonu: {dateText(status.currentPeriodEndsAt)}
                        </AppText>
                        <AppText>{label(status.status)}</AppText>
                        <Button
                          label="Business kurulumuna devam et"
                          disabled={action.busy}
                          onPress={() => void action.run(continueBusiness)}
                        />
                        <Button
                          label="Aboneliği Yönet"
                          variant="text"
                          disabled={action.busy}
                          onPress={() => void action.run(manage)}
                        />
                      </>
                    ) : (
                      <>
                        <Gap />
                        <Button
                          label="Business’a Geç"
                          disabled={
                            action.busy || !pkg || !data.data?.configured
                          }
                          onPress={() =>
                            perform(async () => {
                              const verified = await billing.purchasePlan(plan);
                              if (verified.status.currentPlan === 'BUSINESS') {
                                await refreshProfile();
                                await continueBusiness();
                                return 'Business aboneliğiniz doğrulandı. Şirket kurulumuna devam edebilirsiniz.';
                              }
                              return 'Abonelik mağazada aktif olabilir; yeniden ödeme yapmadan sunucu onayını kontrol edin.';
                            })
                          }
                        />
                      </>
                    )}
                  </Card>
                );
              })}
          {workspace === 'PERSONAL' && (
            <Button
              label="Başlangıç kredilerimi kontrol et"
              variant="text"
              disabled={action.busy}
              onPress={() => perform(welcomeCredits)}
            />
          )}
          <Button
            label="Satın Almaları Geri Yükle"
            variant="outlined"
            disabled={action.busy}
            onPress={() =>
              perform(async () => {
                await billing.restore();
                return 'Satın alma durumu sunucudan kontrol edildi.';
              })
            }
          />
        </>
      )}
    </Page>
  );
}
