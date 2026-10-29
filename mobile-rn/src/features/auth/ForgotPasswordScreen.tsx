import { useState } from 'react';
import { View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import {
  AppText,
  AuthShell,
  Button,
  Field,
  Gap,
  Icon,
} from '../../design/components';
import { brand, fonts } from '../../design/tokens';
import {
  emailError,
  passwordError,
  resetPassword,
  sendResetCode,
} from './auth';
import { useAction } from './useAction';

export default function ForgotPasswordScreen() {
  const router = useRouter();
  const [email, setEmail] = useState(''),
    [sent, setSent] = useState(false),
    [submitted, setSubmitted] = useState(false);
  const [code, setCode] = useState(''),
    [password, setPassword] = useState(''),
    [confirm, setConfirm] = useState('');
  const { busy, run, show } = useAction();
  const codeError = /^\d{6}$/.test(code)
    ? undefined
    : 'Doğrulama kodu 6 haneli olmalıdır.';
  const confirmError =
    confirm !== password ? 'Yeni şifreler eşleşmiyor.' : passwordError(confirm);
  const submit = () => {
    setSubmitted(true);
    if (!sent) {
      if (emailError(email)) return;
      void run(
        () => sendResetCode(email),
        () => {
          setSent(true);
          setSubmitted(false);
          show(
            'Bu e-posta ile kayıtlı bir hesap varsa şifre sıfırlama kodu gönderildi.',
          );
        },
      );
    } else {
      if (codeError || passwordError(password) || confirmError) return;
      void run(
        () => resetPassword(email, code, password, confirm),
        () => {
          show(
            'Şifreniz başarıyla değiştirildi. Yeni şifrenizle giriş yapabilirsiniz.',
          );
          router.replace('/login');
        },
      );
    }
  };
  return (
    <AuthShell>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14 }}>
        <LinearGradient
          colors={[brand.primary, brand.secondary]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={{
            width: 54,
            height: 54,
            borderRadius: 18,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="reset" size={27} color="#FFFFFF" />
        </LinearGradient>
        <AppText
          variant="titleLarge"
          accessibilityRole="header"
          style={{ fontFamily: fonts.black, fontWeight: '900', flex: 1 }}
        >
          Şifremi Unuttum
        </AppText>
      </View>
      <Gap size={22} />
      <AppText>
        {sent
          ? 'E-postanıza gönderilen kodu girerek yeni şifrenizi belirleyin.'
          : 'Hesabınıza ait e-posta adresini girin. Size bir şifre sıfırlama kodu göndereceğiz.'}
      </AppText>
      <Gap size={22} />
      {!sent ? (
        <Field
          label="E-posta"
          placeholder="ornek@email.com"
          icon="email"
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          autoComplete="email"
          textContentType="emailAddress"
          error={submitted ? emailError(email) : undefined}
          editable={!busy}
          returnKeyType="done"
          onSubmitEditing={() => {
            if (!busy) submit();
          }}
        />
      ) : (
        <>
          <Field
            label="Doğrulama Kodu"
            placeholder="6 haneli kod"
            icon="password"
            value={code}
            onChangeText={(text) =>
              setCode(text.replace(/\D/g, '').slice(0, 6))
            }
            maxLength={6}
            keyboardType="number-pad"
            autoComplete="one-time-code"
            textContentType="oneTimeCode"
            editable={!busy}
            error={submitted ? codeError : undefined}
          />
          <Gap />
          <Field
            label="Yeni Şifre"
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
            label="Yeni Şifre Tekrar"
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
        </>
      )}
      <Gap size={22} />
      <Button
        label={sent ? 'Şifreyi Değiştir' : 'Kod Gönder'}
        icon={sent ? 'reset' : 'send'}
        loading={busy}
        onPress={submit}
      />
      {sent && (
        <>
          <Gap size={12} />
          <Button
            label="E-posta adresini değiştir"
            variant="text"
            disabled={busy}
            onPress={() => {
              setSent(false);
              setSubmitted(false);
              setCode('');
              setPassword('');
              setConfirm('');
            }}
          />
        </>
      )}
      <Gap />
      <Button
        label="Giriş ekranına dön"
        variant="text"
        icon="back"
        disabled={busy}
        onPress={() => router.replace('/login')}
      />
    </AuthShell>
  );
}
