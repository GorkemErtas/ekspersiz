import { useRef, useState } from 'react';
import { View, type TextInputInstance } from 'react-native';
import { useRouter } from 'expo-router';
import {
  AppText,
  AuthShell,
  Button,
  Field,
  FormHeading,
  Gap,
} from '../../design/components';
import { useTheme } from '../../design/ThemeProvider';
import { emailError, googleLogin, login } from './auth';
import { useAction } from './useAction';

export default function LoginScreen() {
  const router = useRouter();
  const { colors } = useTheme();
  const [email, setEmail] = useState(''),
    [password, setPassword] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const passwordRef = useRef<TextInputInstance>(null);
  const { busy, run } = useAction();
  const submit = () => {
    setSubmitted(true);
    if (emailError(email) || !password) return;
    void run(
      () => login(email, password),
      () => router.replace('/main'),
    );
  };
  return (
    <AuthShell>
      <FormHeading
        title="Tekrar hoş geldiniz"
        description="Hesabınıza giriş yaparak araç analizlerinize devam edin."
      />
      <Field
        label="E-posta"
        placeholder="ornek@email.com"
        icon="email"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoComplete="email"
        textContentType="emailAddress"
        returnKeyType="next"
        onSubmitEditing={() => passwordRef.current?.focus()}
        error={submitted ? emailError(email) : undefined}
      />
      <Gap />
      <Field
        ref={passwordRef}
        label="Şifre"
        placeholder="Şifrenizi girin"
        icon="lock"
        password
        value={password}
        onChangeText={setPassword}
        autoComplete="current-password"
        textContentType="password"
        returnKeyType="done"
        onSubmitEditing={() => {
          if (!busy) submit();
        }}
        editable={!busy}
        error={submitted && !password ? 'Şifrenizi girin.' : undefined}
      />
      <Gap size={8} />
      <View style={{ alignItems: 'flex-end' }}>
        <Button
          label="Şifremi unuttum?"
          variant="text"
          disabled={busy}
          onPress={() => router.push('/forgot-password')}
        />
      </View>
      <Gap size={12} />
      <Button label="Giriş Yap" icon="login" loading={busy} onPress={submit} />
      <Gap size={22} />
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
        <View style={{ height: 1, backgroundColor: colors.border, flex: 1 }} />
        <AppText variant="bodySmall">veya</AppText>
        <View style={{ height: 1, backgroundColor: colors.border, flex: 1 }} />
      </View>
      <Gap size={22} />
      <Button
        label="Google ile Devam Et"
        variant="outlined"
        icon="google"
        disabled={busy}
        onPress={() => {
          void run(googleLogin, () => router.replace('/main'));
        }}
      />
      <Gap size={12} />
      <Button
        label="Yeni Hesap Oluştur"
        variant="outlined"
        icon="personAdd"
        disabled={busy}
        onPress={() => router.push('/register')}
      />
    </AuthShell>
  );
}
