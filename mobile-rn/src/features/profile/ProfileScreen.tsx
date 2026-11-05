import { TouchSurface } from '../../design/TouchSurface';
import { radius, spacing } from '../../design/tokens';
import { View } from 'react-native';
import { useRouter } from 'expo-router';
import { api, session, useSession } from '../../core/runtime';
import { billingApi, refreshProfile } from '../../core/services';
import { useResource } from '../../core/queries';
import { unregisterDevice, registerDevice } from '../../platform/push';
import {
  AppText,
  Button,
  Card,
  Gap,
  Icon,
  type IconName,
} from '../../design/components';
import { Page, confirm } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import { useAction } from '../auth/useAction';
function Row({
  icon,
  title,
  value,
  onPress,
}: {
  icon: IconName;
  title: string;
  value: string;
  onPress?: () => void;
}) {
  const { colors } = useTheme();
  return (
    <TouchSurface
      disabled={!onPress}
      accessibilityRole={onPress ? 'button' : undefined}
      onPress={onPress}
      style={{
        paddingHorizontal: spacing.m,
        paddingVertical: spacing.m,
        flexDirection: 'row',
        alignItems: 'center',
        gap: spacing.sm,
      }}
    >
      <View
        style={{
          height: 42,
          width: 42,
          borderRadius: radius.small,
          backgroundColor: colors.primaryContainer,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={icon} size={21} color={colors.primary} />
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        {onPress ? (
          <>
            <AppText variant="bodyLarge" style={{ fontWeight: '800' }}>
              {title}
            </AppText>
            <View style={{ height: 4 }} />
            <AppText variant="bodySmall">{value}</AppText>
          </>
        ) : (
          <>
            <AppText variant="bodySmall" style={{ fontWeight: '600' }}>
              {title}
            </AppText>
            <View style={{ height: 4 }} />
            <AppText variant="bodyLarge" style={{ fontWeight: '800' }}>
              {value}
            </AppText>
          </>
        )}
      </View>
      {onPress && <Icon name="chevron" color={colors.secondaryText} />}
    </TouchSurface>
  );
}
function Divider() {
  const { colors } = useTheme();
  return (
    <View
      style={{ height: 1, marginLeft: 82, backgroundColor: colors.border }}
    />
  );
}
export default function ProfileScreen({
  embedded = false,
}: {
  embedded?: boolean;
}) {
  const { profile, workspace } = useSession(),
    router = useRouter(),
    { colors } = useTheme(),
    action = useAction(),
    credits = useResource('credits', billingApi.credits),
    billing = useResource('billing', billingApi.overview);
  if (!profile) return null;
  const account =
      workspace === 'BUSINESS' ? credits.data?.company : credits.data?.personal,
    plan = billing.data?.status.currentPlan ?? profile.subscriptionPlan,
    planLabel =
      plan === 'FREE'
        ? 'Kredi hesabı'
        : ['PLUS', 'PRO'].includes(plan)
          ? 'Kredi hesabı · Önceki dönem hakları aktif'
          : 'Business';
  const parts = profile.fullName.trim().split(/\s+/),
    initials =
      `${parts[0]?.[0] ?? 'E'}${parts.length > 1 ? (parts.at(-1)?.[0] ?? '') : ''}`.toLocaleUpperCase(
        'tr-TR',
      );
  const balance = account
    ? `${workspace === 'BUSINESS' ? 'Şirket' : 'Kişisel'}: ${account.balances.ANALYSIS?.available ?? 0} analiz · ${account.balances.ASSISTANT?.available ?? 0} asistan\n${account.usedSlots} / ${account.totalSlots} araç slotu`
    : 'Analiz, asistan ve araç kapasitenizi yönetin.';
  return (
    <Page
      title="Profil"
      back={!embedded}
      embedded={embedded}
      onRefresh={() => void action.run(refreshProfile)}
      refreshing={action.busy}
    >
      <View
        style={{ alignItems: 'center', paddingVertical: 16, marginBottom: 5 }}
      >
        <View
          style={{
            width: 66,
            height: 66,
            borderRadius: 24,
            backgroundColor: colors.primaryContainer,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <AppText
            variant="headlineMedium"
            style={{ fontWeight: '900', color: colors.onPrimaryContainer }}
          >
            {initials}
          </AppText>
        </View>
        <Gap />
        <AppText
          variant="headlineSmall"
          style={{ fontWeight: '900', textAlign: 'center' }}
        >
          {profile.fullName}
        </AppText>
        <View style={{ height: 14 }} />
        <View
          style={{
            flexDirection: 'row',
            flexWrap: 'wrap',
            justifyContent: 'center',
            gap: 8,
          }}
        >
          <View
            style={{
              flexDirection: 'row',
              maxWidth: '100%',
              alignItems: 'center',
              gap: spacing.s,
              paddingHorizontal: 12,
              paddingVertical: 6,
              borderRadius: 99,
              borderWidth: 1,
              borderColor: colors.border,
              backgroundColor: colors.high,
            }}
          >
            <Icon name="premium" size={14} color={colors.secondaryText} />
            <AppText
              variant="bodySmall"
              style={{ fontWeight: '700', flexShrink: 1 }}
            >
              {planLabel}
            </AppText>
          </View>
          {profile.businessAccount && (
            <View style={{ padding: 8 }}>
              <AppText variant="bodySmall">
                {profile.businessAccount.role === 'OWNER'
                  ? 'Şirket sahibi'
                  : 'Şirket üyesi'}
              </AppText>
            </View>
          )}
        </View>
      </View>
      <Card style={{ padding: 0 }}>
        <Row icon="person" title="Ad Soyad" value={profile.fullName} />
        <Divider />
        <Row icon="email" title="E-posta" value={profile.email} />
        <Divider />
        <Row icon="premium" title="Abonelik durumu" value={planLabel} />
        {profile.businessAccount && (
          <>
            <Divider />
            <Row
              icon="shield"
              title="Şirket erişimi"
              value={
                profile.businessAccount.workspaceAvailable
                  ? 'Şirket çalışma alanı aktif.'
                  : 'Şirket erişimi aktif değil. Kişisel araçlarınız ve kredileriniz korunur.'
              }
            />
            <Divider />
            <Row
              icon="business"
              title="Şirket"
              value={profile.businessAccount.companyName}
            />
          </>
        )}
      </Card>
      <View style={{ marginTop: 5 }}>
        <Card style={{ padding: 0 }}>
          <Row
            icon="premium"
            title="Krediler ve Paketler"
            value={balance}
            onPress={() => router.push('/billing')}
          />
          <Divider />
          <Row
            icon={profile.businessAccount ? 'business' : 'verifiedEmail'}
            title={
              profile.businessAccount
                ? 'Şirket İşlemleri'
                : plan === 'BUSINESS'
                  ? 'Şirketini oluştur'
                  : 'Şirket Daveti'
            }
            value={
              profile.businessAccount
                ? 'Çalışanları görüntüleyin, davet edin ve yönetin.'
                : plan === 'BUSINESS'
                  ? 'Şirket oluşturun veya bir şirket davetini kabul edin.'
                  : 'E-postanıza gönderilen şirket davetini kabul edin.'
            }
            onPress={() => router.push('/business')}
          />
          <Divider />
          <Row
            icon="report"
            title="Uygulama Rehberi"
            value="EksperSiz’i birkaç adımda yeniden keşfet."
            onPress={() => router.push('/guide')}
          />
          <Divider />
          <Row
            icon="reset"
            title="Şifre Değiştir"
            value="Hesap şifrenizi güvenli şekilde güncelleyin."
            onPress={() => router.push('/change-password')}
          />
        </Card>
      </View>
      <View style={{ marginTop: 5 }}>
        <Card style={{ backgroundColor: colors.low }}>
          <View style={{ flexDirection: 'row', gap: 12 }}>
            <Icon name="shield" color={colors.info} />
            <View style={{ flex: 1, minWidth: 0 }}>
              <AppText variant="titleSmall" style={{ fontWeight: '900' }}>
                EksperSiz
              </AppText>
              <View style={{ height: 4 }} />
              <AppText variant="bodySmall" style={{ lineHeight: 17.4 }}>
                Araç hasarlarını yapay zekâ destekli görüntü analizi ile
                inceleyin.
              </AppText>
            </View>
          </View>
        </Card>
      </View>
      <Button
        label="Bildirimleri etkinleştir"
        variant="outlined"
        icon="bell"
        loading={action.busy}
        onPress={() =>
          void action.run(
            () => registerDevice(true),
            () => action.show('Bildirim kaydı kontrol edildi.'),
          )
        }
      />
      <Button
        label="Çıkış Yap"
        icon="logout"
        variant="outlined"
        disabled={action.busy}
        onPress={() =>
          confirm(
            'Çıkış yapılsın mı?',
            'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
            () =>
              void action.run(async () => {
                await unregisterDevice();
                await session.logout();
              }),
          )
        }
      />
      <Button
        label="Hesabımı Sil"
        icon="delete"
        variant="danger"
        disabled={action.busy}
        onPress={() =>
          confirm(
            'Hesap silinsin mi?',
            'Bu işlem hesabınızı ve kişisel kayıtlarınızı kalıcı olarak siler. Aktif mağaza aboneliğiniz varsa önce mağazadan iptal edin.',
            () =>
              void action.run(async () => {
                await unregisterDevice();
                await api.request('/auth/account', { method: 'DELETE' });
                await session.logout();
              }),
            true,
          )
        }
      />
    </Page>
  );
}
