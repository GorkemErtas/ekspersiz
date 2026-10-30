import { api, session } from '../../core/runtime';
import { isRecord, parseProfile } from '../../core/contracts';
import { ApiError } from '../../core/api';

export const normalizeEmail = (email: string) => email.trim().toLowerCase();
export const emailError = (value: string) =>
  !value.trim()
    ? 'E-posta adresinizi girin.'
    : !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value.trim())
      ? 'Geçerli bir e-posta adresi girin.'
      : undefined;
export const passwordError = (value: string) =>
  value.length < 8
    ? 'Şifre en az 8 karakter olmalıdır.'
    : value.length > 72
      ? 'Şifre en fazla 72 karakter olabilir.'
      : undefined;

async function acceptLogin(response: unknown, generation: number) {
  if (!isRecord(response) || typeof response.accessToken !== 'string')
    throw new Error('Sunucudan geçersiz giriş yanıtı alındı.');
  await session.authenticate(
    response.accessToken,
    parseProfile(response, true),
    generation,
  );
}
export async function login(email: string, password: string) {
  const generation = session.beginLogin();
  try {
    const response = await api.request('/auth/login', {
      method: 'POST',
      auth: false,
      body: { email: normalizeEmail(email), password },
    });
    await acceptLogin(response, generation);
  } catch (error) {
    if (error instanceof ApiError && error.status === 401)
      throw new Error('E-posta veya şifre hatalı.');
    throw error;
  }
}
let googleBusy = false;
export async function googleLogin() {
  if (googleBusy) throw new Error('Google giriş işlemi devam ediyor.');
  const clientId = process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID;
  if (!clientId) throw new Error('Google Sign-In yapılandırması bulunamadı.');
  googleBusy = true;
  try {
    const generation = session.beginLogin();
    // Load the native SDK only on the explicit Google action. Metro resolves this
    // synchronously without adding native-module initialization to app startup.
    const { GoogleSignin, isSuccessResponse } =
      // eslint-disable-next-line @typescript-eslint/no-require-imports -- Defer the native SDK until the user chooses Google login.
      require('@react-native-google-signin/google-signin') as typeof import('@react-native-google-signin/google-signin');
    GoogleSignin.configure({
      webClientId: clientId,
      iosClientId: process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID,
    });
    await GoogleSignin.hasPlayServices({ showPlayServicesUpdateDialog: true });
    session.check(generation);
    // Google retains its native account after our JWT is cleared. Reset local
    // selection so shared devices can choose a different account; never revoke access.
    if (GoogleSignin.getCurrentUser()) await GoogleSignin.signOut();
    session.check(generation);
    const result = await GoogleSignin.signIn();
    session.check(generation);
    if (!isSuccessResponse(result)) return;
    if (!result.data.idToken)
      throw new Error('Google kimlik doğrulama tokenı alınamadı.');
    const response = await api.request('/auth/google', {
      method: 'POST',
      auth: false,
      body: { idToken: result.data.idToken },
    });
    await acceptLogin(response, generation);
  } finally {
    googleBusy = false;
  }
}
export async function restoreSession() {
  await session.restore();
  const { token, generation } = session.getSnapshot();
  if (!token) return;
  const profile = parseProfile(await api.request('/auth/me'));
  await session.authenticate(token, profile, generation);
}
export function register(fullName: string, email: string, password: string) {
  return api.request('/auth/register', {
    method: 'POST',
    auth: false,
    body: { fullName: fullName.trim(), email: normalizeEmail(email), password },
  });
}
export function verifyEmail(email: string, code: string) {
  return api.request('/auth/verify-email', {
    method: 'POST',
    auth: false,
    body: { email: normalizeEmail(email), code: code.trim() },
  });
}
export function resendVerification(email: string) {
  return api.request('/auth/resend-verification', {
    method: 'POST',
    auth: false,
    body: { email: normalizeEmail(email) },
  });
}
export function sendResetCode(email: string) {
  return api.request('/auth/forgot-password', {
    method: 'POST',
    auth: false,
    body: { email: normalizeEmail(email) },
  });
}
export function resetPassword(
  email: string,
  code: string,
  newPassword: string,
  confirmNewPassword: string,
) {
  return api.request('/auth/reset-password', {
    method: 'POST',
    auth: false,
    body: {
      email: normalizeEmail(email),
      code: code.trim(),
      newPassword,
      confirmNewPassword,
    },
  });
}
