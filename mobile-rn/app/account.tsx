import { Alert, ScrollView, View } from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { api, session, useSession } from '../src/core/runtime';
import { parseProfile } from '../src/core/contracts';
import { AppText, Button, Card, Gap } from '../src/design/components';
import { useTheme } from '../src/design/ThemeProvider';
import { fonts } from '../src/design/tokens';
import { useAction } from '../src/features/auth/useAction';

/** Auth/workspace integration surface; full Flutter Profile/MainShell port is pending. */
export default function Account() {
  const { profile, workspace } = useSession();
  const { colors, mode, toggle } = useTheme();
  const { busy, run } = useAction();
  const router = useRouter();
  if (!profile) return null;
  const initials = profile.fullName
    .trim()
    .split(/\s+/)
    .map((part) => Array.from(part)[0])
    .filter(Boolean);
  return (
    <SafeAreaView style={{ flex: 1 }}>
      <ScrollView
        contentContainerStyle={{
          padding: 18,
          paddingBottom: 110,
          alignItems: 'center',
        }}
      >
        <View style={{ width: '100%', maxWidth: 760 }}>
          <AppText variant="titleLarge" accessibilityRole="header">
            Profil
          </AppText>
          <Gap size={30} />
          <View style={{ alignItems: 'center', paddingVertical: 16 }}>
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
                style={{ color: colors.onPrimaryContainer }}
              >
                {`${initials[0] ?? ''}${initials.length > 1 ? initials.at(-1) : ''}`.toLocaleUpperCase(
                  'tr-TR',
                )}
              </AppText>
            </View>
            <Gap />
            <AppText
              variant="headlineSmall"
              style={{
                fontFamily: fonts.black,
                fontWeight: '900',
                textAlign: 'center',
              }}
            >
              {profile.fullName}
            </AppText>
          </View>
          <Gap size={20} />
          <Card>
            <AppText variant="bodySmall">Ad Soyad</AppText>
            <AppText variant="bodyLarge">{profile.fullName}</AppText>
            <Gap />
            <AppText variant="bodySmall">E-posta</AppText>
            <AppText variant="bodyLarge">{profile.email}</AppText>
            <Gap />
            <AppText variant="bodySmall">Abonelik durumu</AppText>
            <AppText variant="bodyLarge">{profile.subscriptionPlan}</AppText>
            {profile.businessAccount && (
              <>
                <Gap />
                <AppText variant="bodySmall">Şirket</AppText>
                <AppText variant="bodyLarge">
                  {profile.businessAccount.companyName}
                </AppText>
                <Gap />
                <AppText>
                  {profile.businessAccount.role === 'OWNER'
                    ? 'Şirket sahibi'
                    : 'Şirket üyesi'}
                </AppText>
                <AppText>
                  Şirket erişimi:{' '}
                  {profile.businessAccount.workspaceAccessStatus}
                </AppText>
              </>
            )}
          </Card>
          <Gap />
          <Button
            label={
              workspace === 'PERSONAL'
                ? 'Kişisel çalışma alanı'
                : (profile.businessAccount?.companyName ??
                  'Şirket çalışma alanı')
            }
            icon={workspace === 'PERSONAL' ? 'person' : 'business'}
            variant="outlined"
            disabled={busy}
            onPress={() => {
              const target = workspace === 'PERSONAL' ? 'BUSINESS' : 'PERSONAL';
              void run(() =>
                session.select(target, () =>
                  api.request('/workspace', { workspace: target }),
                ),
              );
            }}
          />
          <Gap />
          <Button
            label="Hesabı yenile"
            icon="refresh"
            variant="outlined"
            loading={busy}
            onPress={() => {
              void run(() =>
                session.refreshProfile(async () =>
                  parseProfile(await api.request('/auth/me')),
                ),
              );
            }}
          />
          <Gap />
          <Button
            label={mode === 'dark' ? 'Açık tema' : 'Koyu tema'}
            icon={mode === 'dark' ? 'light' : 'dark'}
            variant="outlined"
            onPress={toggle}
          />
          <Gap />
          <Button
            label="Şifre Değiştir"
            icon="lock"
            variant="outlined"
            disabled={busy}
            onPress={() => router.push('/change-password')}
          />
          <Gap />
          <Button
            label="Çıkış Yap"
            icon="logout"
            disabled={busy}
            onPress={() =>
              Alert.alert(
                'Çıkış yapılsın mı?',
                'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
                [
                  { text: 'İptal', style: 'cancel' },
                  {
                    text: 'Çıkış Yap',
                    onPress: () => {
                      void run(() => session.logout());
                    },
                  },
                ],
              )
            }
          />
          <Gap />
          <Button
            label="Hesabımı Sil"
            icon="delete"
            variant="text"
            disabled={busy}
            onPress={() =>
              Alert.alert(
                'Hesabınızı silmek istiyor musunuz?',
                'Bu işlem geri alınamaz. Hesabınız ve hesabınıza ait kişisel veriler kalıcı olarak silinecektir.',
                [
                  { text: 'İptal', style: 'cancel' },
                  {
                    text: 'Hesabımı Sil',
                    style: 'destructive',
                    onPress: () => {
                      void run(async () => {
                        await api.request('/auth/account', {
                          method: 'DELETE',
                        });
                        await session.logout();
                      });
                    },
                  },
                ],
              )
            }
          />
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
