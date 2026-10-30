import { useState } from 'react';
import { View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import {
  AppText,
  AuthShell,
  Button,
  Field,
  Gap,
  Icon,
} from '../../design/components';
import { brand, fonts, spacing } from '../../design/tokens';
import { useTheme } from '../../design/ThemeProvider';
import { resendVerification, verifyEmail } from './auth';
import { useAction } from './useAction';

export default function VerifyEmailScreen() {
  const params = useLocalSearchParams<{ email: string }>();
  const email = typeof params.email === 'string' ? params.email : '';
  const router = useRouter();
  const { colors } = useTheme();
  const [code, setCode] = useState(''),
    [submitted, setSubmitted] = useState(false);
  const { busy, run, show } = useAction();
  const [resending, setResending] = useState(false);
  const submit = () => {
    setSubmitted(true);
    if (!/^\d{6}$/.test(code) || !email) return;
    void run(
      () => verifyEmail(email, code),
      () => {
        show('E-posta adresiniz doğrulandı. Şimdi giriş yapabilirsiniz.');
        router.replace('/login');
      },
    );
  };
  return (
    <AuthShell maxWidth={520}>
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
          <Icon name="verifiedEmail" size={27} color="#FFFFFF" />
        </LinearGradient>
        <View style={{ flex: 1 }}>
          <AppText
            variant="titleMedium"
            style={{ fontFamily: fonts.medium, fontWeight: '900' }}
          >
            E-postanı doğrula
          </AppText>
          <Gap size={2} />
          <AppText variant="bodySmall">EksperSiz hesabını aktifleştir</AppText>
        </View>
      </View>
      <Gap size={30} />
      <AppText
        variant="headlineSmall"
        accessibilityRole="header"
        style={{ fontFamily: fonts.black, fontWeight: '900' }}
      >
        Doğrulama kodunu gir
      </AppText>
      <Gap size={8} />
      <AppText>{email} adresine gönderdiğimiz 6 haneli kodu girin.</AppText>
      <Gap size={26} />
      <Field
        label="Doğrulama Kodu"
        placeholder="123456"
        icon="password"
        value={code}
        onChangeText={(text) => setCode(text.replace(/\D/g, '').slice(0, 6))}
        maxLength={6}
        keyboardType="number-pad"
        autoComplete="one-time-code"
        textContentType="oneTimeCode"
        autoFocus
        editable={!busy}
        style={{
          fontSize: 22,
          letterSpacing: 8,
          textAlign: 'center',
          fontFamily: fonts.extraBold,
        }}
        error={
          submitted && !/^\d{6}$/.test(code)
            ? 'Doğrulama kodu 6 haneli olmalıdır.'
            : undefined
        }
        onSubmitEditing={() => {
          if (!busy) submit();
        }}
      />
      <Gap size={12} />
      <View
        style={{
          backgroundColor: colors.low,
          borderRadius: 16,
          padding: 14,
          flexDirection: 'row',
          gap: 10,
        }}
      >
        <Icon name="clock" size={19} color={colors.primary} />
        <AppText variant="bodySmall" style={{ flex: 1 }}>
          Doğrulama kodu 5 dakika boyunca geçerlidir.
        </AppText>
      </View>
      <Gap size={spacing.l} />
      <Button
        label="E-postayı Doğrula"
        icon="verified"
        loading={busy && !resending}
        disabled={busy}
        onPress={submit}
      />
      <Gap />
      <Button
        label={resending ? 'Kod gönderiliyor...' : 'Kodu Tekrar Gönder'}
        icon="refresh"
        variant="outlined"
        disabled={busy || !email}
        onPress={() => {
          void run(async () => {
            setResending(true);
            try {
              await resendVerification(email);
              show('Doğrulama kodu tekrar gönderildi.');
            } finally {
              setResending(false);
            }
          });
        }}
      />
      <Gap size={12} />
      <Button
        label="Giriş ekranına dön"
        icon="back"
        variant="text"
        disabled={busy}
        onPress={() => router.replace('/login')}
      />
    </AuthShell>
  );
}
