import { isRecord } from '../../core/contracts';
import { api } from '../../core/runtime';
import {
  emailError,
  normalizeEmail,
  passwordError,
  register,
  resendVerification,
  resetPassword,
  sendResetCode,
  verifyEmail,
} from './auth';

jest.mock('../../core/runtime', () => ({
  api: { request: jest.fn(async () => undefined) },
  session: {},
}));
beforeEach(() => jest.clearAllMocks());
test('email normalization and validation preserve Turkish client contract', () => {
  expect(normalizeEmail('  USER@Example.com ')).toBe('user@example.com');
  expect(emailError('a@b')).toBeDefined();
  expect(emailError('a@example.com')).toBeUndefined();
  expect(passwordError('1234567')).toBeDefined();
  expect(passwordError('a'.repeat(73))).toBeDefined();
});
test('registration sends only existing fields with unchanged password bytes', async () => {
  await register(
    ' Deniz Yılmaz ',
    ' DENIZ@Example.com ',
    ' unchanged password ',
  );
  expect(api.request).toHaveBeenCalledWith('/auth/register', {
    method: 'POST',
    auth: false,
    body: {
      fullName: 'Deniz Yılmaz',
      email: 'deniz@example.com',
      password: ' unchanged password ',
    },
  });
});
test('verification and resend remain separate unauthenticated endpoints', async () => {
  await verifyEmail(' DENIZ@Example.com ', ' 123456 ');
  await resendVerification('DENIZ@example.com');
  expect(api.request).toHaveBeenNthCalledWith(1, '/auth/verify-email', {
    method: 'POST',
    auth: false,
    body: { email: 'deniz@example.com', code: '123456' },
  });
  expect(api.request).toHaveBeenNthCalledWith(2, '/auth/resend-verification', {
    method: 'POST',
    auth: false,
    body: { email: 'deniz@example.com' },
  });
});
test('password reset uses code/newPassword/confirmNewPassword contract', async () => {
  await sendResetCode('DENIZ@example.com');
  await resetPassword(
    'DENIZ@example.com',
    '123456',
    'newPassword',
    'newPassword',
  );
  expect(api.request).toHaveBeenNthCalledWith(1, '/auth/forgot-password', {
    method: 'POST',
    auth: false,
    body: { email: 'deniz@example.com' },
  });
  expect(api.request).toHaveBeenNthCalledWith(2, '/auth/reset-password', {
    method: 'POST',
    auth: false,
    body: {
      email: 'deniz@example.com',
      code: '123456',
      newPassword: 'newPassword',
      confirmNewPassword: 'newPassword',
    },
  });
});
test('arrays cannot be mistaken for API objects', () => {
  expect(isRecord([])).toBe(false);
});
