import { useState } from 'react';
import { ScrollView, View } from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { api, session } from '../../core/runtime';
import { AppText, Button, Card, Field, Gap } from '../../design/components';
import { fonts } from '../../design/tokens';
import { passwordError } from './auth';
import { useAction } from './useAction';

export default function ChangePasswordScreen() {
  const router = useRouter();
  const [current, setCurrent] = useState(''),
    [password, setPassword] = useState(''),
    [confirm, setConfirm] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const { busy, run, show } = useAction();
  const nextError =
    password === current
      ? 'Yeni şifre mevcut şifreden farklı olmalıdır.'
      : passwordError(password);
  const confirmError =
    confirm !== password ? 'Yeni şifreler eşleşmiyor.' : passwordError(confirm);
  const submit = () => {
    setSubmitted(true);
    if (!current || nextError || confirmError) return;
    void run(
      () =>
        api.request('/auth/change-password', {
          method: 'POST',
          body: {
            currentPassword: current,
            newPassword: password,
            confirmNewPassword: confirm,
          },
        }),
      () => {
        show('Şifreniz başarıyla değiştirildi.');
        router.replace(session.getSnapshot().profile ? '/account' : '/login');
      },
    );
  };
  return (
    <SafeAreaView style={{ flex: 1 }}>
      <ScrollView
        keyboardShouldPersistTaps="handled"
        automaticallyAdjustKeyboardInsets
        contentContainerStyle={{
          paddingHorizontal: 18,
          paddingTop: 15,
          paddingBottom: 110,
          alignItems: 'center',
        }}
      >
        <View style={{ width: '100%', maxWidth: 640 }}>
          <View
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              minHeight: 60,
            }}
          >
            <Button
              label="Geri"
              variant="text"
              icon="back"
              onPress={() => router.back()}
            />
            <AppText variant="titleLarge">Şifre Değiştir</AppText>
          </View>
          <Card>
            <AppText
              variant="headlineSmall"
              style={{ fontFamily: fonts.black, fontWeight: '900' }}
            >
              Hesap güvenliği
            </AppText>
            <Gap size={8} />
            <AppText>
              Şifrenizi değiştirmek için önce mevcut şifrenizi doğrulayın.
            </AppText>
            <Gap size={22} />
            <Field
              label="Mevcut Şifre"
              placeholder="Mevcut şifrenizi girin"
              icon="lock"
              password
              value={current}
              onChangeText={setCurrent}
              autoComplete="current-password"
              textContentType="password"
              editable={!busy}
              error={
                submitted && !current ? 'Mevcut şifrenizi girin.' : undefined
              }
            />
            <Gap />
            <Field
              label="Yeni Şifre"
              placeholder="En az 8 karakter"
              icon="password"
              password
              value={password}
              onChangeText={setPassword}
              autoComplete="new-password"
              textContentType="newPassword"
              editable={!busy}
              error={submitted ? nextError : undefined}
            />
            <Gap />
            <Field
              label="Yeni Şifre Tekrar"
              placeholder="Yeni şifrenizi tekrar girin"
              icon="reset"
              password
              value={confirm}
              onChangeText={setConfirm}
              autoComplete="new-password"
              textContentType="newPassword"
              editable={!busy}
              error={submitted ? confirmError : undefined}
              returnKeyType="done"
              onSubmitEditing={() => {
                if (!busy) submit();
              }}
            />
            <Gap size={14} />
            <AppText variant="bodySmall">
              Yeni şifreniz 8 ile 72 karakter arasında olmalı ve mevcut
              şifrenizden farklı olmalıdır.
            </AppText>
            <Gap size={22} />
            <Button
              label="Şifreyi Güncelle"
              icon="verified"
              loading={busy}
              onPress={submit}
            />
          </Card>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
