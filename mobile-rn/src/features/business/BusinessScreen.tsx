import { useState } from 'react';
import { View } from 'react-native';
import { useRouter } from 'expo-router';
import { api, session, useSession } from '../../core/runtime';
import { business, refreshProfile } from '../../core/services';
import { invalidate, useResource } from '../../core/queries';
import { emailError } from '../auth/auth';
import { useAction } from '../auth/useAction';
import { AppText, Button, Card, Field, Gap } from '../../design/components';
import {
  Badge,
  Heading,
  Page,
  StateView,
  Tile,
  confirm,
} from '../../design/layout';

export default function BusinessScreen() {
  const { profile, workspace } = useSession(),
    router = useRouter(),
    action = useAction();
  const company = profile?.businessAccount;
  const members = useResource(
    'business/members',
    business.members,
    company?.role === 'OWNER',
  );
  const [name, setName] = useState(''),
    [email, setEmail] = useState(''),
    [code, setCode] = useState('');
  const select = async () => {
    await refreshProfile();
    if (!session.getSnapshot().profile?.businessAccount?.workspaceAvailable)
      throw new Error(
        'Şirket erişimi henüz aktif değil. Krediler ve Paketler ekranından yeniden kontrol edin.',
      );
    await session.select('BUSINESS', () =>
      api.request('/workspace', { workspace: 'BUSINESS' }),
    );
  };
  return (
    <Page title="Şirket Yönetimi">
      <Heading
        title={company?.companyName ?? 'Business Çalışma Alanı'}
        description="Şirket araçlarınızı ve ekip üyelerinizi ortak alanda yönetin."
        icon="business"
      />
      {company ? (
        <>
          <Card>
            <Badge
              text={company.role === 'OWNER' ? 'Şirket Sahibi' : 'Şirket Üyesi'}
            />
            <Gap />
            <AppText>
              Şirket erişimi:{' '}
              {company.workspaceAvailable ? 'Aktif' : 'Aktif değil'}
            </AppText>
            {company.sandbox && <AppText>Test aboneliği</AppText>}
            <Gap />
            {company.workspaceAvailable && workspace !== 'BUSINESS' && (
              <Button
                label="Business çalışma alanına geç"
                loading={action.busy}
                onPress={() => void action.run(select)}
              />
            )}
            {!company.workspaceAvailable && (
              <Button
                label="Aboneliği kontrol et"
                onPress={() => router.push('/billing')}
              />
            )}
          </Card>
          {company.role === 'OWNER' && (
            <>
              <Card>
                <AppText variant="titleLarge">Ekip Üyesi Davet Et</AppText>
                <Gap />
                <Field
                  label="E-posta"
                  icon="email"
                  value={email}
                  onChangeText={setEmail}
                  keyboardType="email-address"
                  autoCapitalize="none"
                />
                <Gap />
                <Button
                  label="Davet Gönder"
                  loading={action.busy}
                  onPress={() =>
                    void action.run(async () => {
                      const error = emailError(email);
                      if (error) throw new Error(error);
                      await business.invite(email);
                      setEmail('');
                      action.show(
                        'Davet kodu kullanıcının e-posta adresine gönderildi.',
                      );
                    })
                  }
                />
              </Card>
              <AppText variant="titleLarge">Ekip Üyeleri</AppText>
              {members.isPending || members.error ? (
                <StateView
                  loading={members.isPending}
                  error={members.error}
                  retry={() => void members.refetch()}
                />
              ) : (
                members.data?.map((member) => (
                  <Tile
                    key={member.id}
                    title={member.fullName}
                    subtitle={member.email}
                    icon="person"
                  >
                    <Gap />
                    <View
                      style={{
                        flexDirection: 'row',
                        flexWrap: 'wrap',
                        justifyContent: 'space-between',
                        gap: 8,
                      }}
                    >
                      <Badge
                        text={
                          member.role === 'OWNER'
                            ? 'Şirket sahibi'
                            : 'Ekip üyesi'
                        }
                      />
                      {member.role !== 'OWNER' && (
                        <Button
                          label="Üyeyi kaldır"
                          variant="text"
                          disabled={action.busy}
                          onPress={() =>
                            confirm(
                              'Üye kaldırılsın mı?',
                              `${member.fullName} şirket çalışma alanına erişimini kaybeder.`,
                              () =>
                                void action.run(async () => {
                                  await business.remove(member.id);
                                  await invalidate('business/members');
                                }),
                              true,
                            )
                          }
                        />
                      )}
                    </View>
                  </Tile>
                ))
              )}
            </>
          )}
        </>
      ) : (
        <>
          {profile?.subscriptionPlan === 'BUSINESS' ? (
            <Card>
              <AppText variant="titleLarge">Şirketinizi Oluşturun</AppText>
              <Gap />
              <Field
                label="Şirket Adı"
                icon="business"
                value={name}
                onChangeText={setName}
                maxLength={150}
              />
              <Gap />
              <Button
                label="Şirket Oluştur"
                loading={action.busy}
                onPress={() =>
                  void action.run(async () => {
                    if (name.trim().length < 2)
                      throw new Error('Şirket adını girin.');
                    await refreshProfile();
                    if (!session.getSnapshot().profile?.businessAccount) {
                      if (
                        session.getSnapshot().profile?.subscriptionPlan !==
                        'BUSINESS'
                      )
                        throw new Error('Business aboneliğiniz doğrulanamadı.');
                      await business.create(name);
                    }
                    await select();
                  })
                }
              />
            </Card>
          ) : (
            <Card>
              <AppText>
                Şirket oluşturmak için aktif Business aboneliği gerekir. Davet
                kodunuz varsa mevcut şirkete katılabilirsiniz.
              </AppText>
              <Gap />
              <Button
                label="Business Paketlerini Gör"
                onPress={() => router.push('/billing')}
              />
            </Card>
          )}
          <Card>
            <AppText variant="titleLarge">Şirkete Katıl</AppText>
            <Gap />
            <Field
              label="Davet Kodu"
              icon="verified"
              value={code}
              onChangeText={setCode}
              autoCapitalize="characters"
              maxLength={100}
            />
            <Gap />
            <Button
              label="Daveti Kabul Et"
              loading={action.busy}
              onPress={() =>
                void action.run(async () => {
                  if (!code.trim()) throw new Error('Davet kodunu girin.');
                  await business.accept(code);
                  await select();
                })
              }
            />
          </Card>
        </>
      )}
    </Page>
  );
}
