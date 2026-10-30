import { useState } from 'react';
import { useRouter } from 'expo-router';
import { View } from 'react-native';
import {
  AppText,
  AuthShell,
  Button,
  Field,
  FormHeading,
  Gap,
  Icon,
} from '../../design/components';
import { useTheme } from '../../design/ThemeProvider';
import { emailError, normalizeEmail, passwordError, register } from './auth';
import { useAction } from './useAction';

export default function RegisterScreen() {
  const router = useRouter();
  const { colors } = useTheme();
  const [name, setName] = useState(''),
    [email, setEmail] = useState('');
  const [password, setPassword] = useState(''),
    [confirm, setConfirm] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const { busy, run } = useAction();
  const nameError =
    name.trim().length < 2
      ? 'Ad soyad en az 2 karakter olmalıdır.'
      : name.trim().length > 100
        ? 'Ad soyad en fazla 100 karakter olabilir.'
        : undefined;
  const mailError =
    email.length > 150
      ? 'E-posta en fazla 150 karakter olabilir.'
      : emailError(email);
  const confirmError =
    confirm !== password || !confirm ? 'Şifreler eşleşmiyor.' : undefined;
  const submit = () => {
    setSubmitted(true);
    if (nameError || mailError || passwordError(password) || confirmError)
      return;
    void run(
      () => register(name, email, password),
      () =>
        router.replace({
          pathname: '/verify-email',
          params: { email: normalizeEmail(email) },
        }),
    );
  };
  return (
    <AuthShell maxWidth={520}>
      <FormHeading
        title="Hesabını oluştur"
        description="Araçlarını kaydet ve AI destekli hasar analizlerini tek yerden yönet."
      />
      <Field
        label="Ad Soyad"
        placeholder="Adınız Soyadınız"
        icon="person"
        value={name}
        onChangeText={setName}
        autoCapitalize="words"
        autoComplete="name"
        textContentType="name"
        editable={!busy}
        error={submitted ? nameError : undefined}
      />
      <Gap />
      <Field
        label="E-posta"
        placeholder="ornek@email.com"
        icon="email"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoComplete="email"
        textContentType="emailAddress"
        editable={!busy}
        error={submitted ? mailError : undefined}
      />
      <Gap />
      <Field
        label="Şifre"
        placeholder="En az 8 karakter"
        icon="lock"
        password
        value={password}
        onChangeText={setPassword}
        autoComplete="new-password"
        textContentType="newPassword"
        editable={!busy}
        error={submitted ? passwordError(password) : undefined}
      />
      <Gap />
      <Field
        label="Şifre Tekrar"
        placeholder="Şifrenizi tekrar girin"
        icon="lock"
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
      <View
        style={{
          backgroundColor: colors.low,
          borderRadius: 16,
          padding: 14,
          flexDirection: 'row',
          gap: 10,
        }}
      >
        <Icon name="lock" size={19} color={colors.primary} />
        <AppText variant="bodySmall" style={{ flex: 1 }}>
          Şifreniz en az 8, en fazla 72 karakter olmalıdır.
        </AppText>
      </View>
      <Gap size={22} />
      <Button
        label="Hesap Oluştur"
        icon="personAdd"
        loading={busy}
        onPress={submit}
      />
      <Gap size={18} />
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
        <View style={{ height: 1, backgroundColor: colors.border, flex: 1 }} />
        <AppText variant="bodySmall">veya</AppText>
        <View style={{ height: 1, backgroundColor: colors.border, flex: 1 }} />
      </View>
      <Gap size={18} />
      <Button
        label="Zaten Hesabım Var"
        icon="login"
        variant="outlined"
        disabled={busy}
        onPress={() => router.replace('/login')}
      />
    </AuthShell>
  );
}
