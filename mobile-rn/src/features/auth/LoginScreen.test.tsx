import { act, fireEvent, render, screen } from '@testing-library/react-native';
import LoginScreen from './LoginScreen';
import { googleLogin, login } from './auth';

const mockPush = jest.fn();
const mockReplace = jest.fn();
jest.mock('expo-router', () => ({
  useRouter: () => ({ push: mockPush, replace: mockReplace }),
}));
jest.mock('./auth', () => ({
  ...jest.requireActual('./auth'),
  login: jest.fn(),
  googleLogin: jest.fn(),
}));

beforeEach(() => jest.clearAllMocks());
test('Turkish login validates fields without requesting authentication', async () => {
  await render(<LoginScreen />);
  await fireEvent.press(screen.getByRole('button', { name: 'Giriş Yap' }));
  expect(screen.getByText('E-posta adresinizi girin.')).toBeTruthy();
  expect(screen.getByText('Şifrenizi girin.')).toBeTruthy();
  expect(login).not.toHaveBeenCalled();
});
test('pending login retains its label, disables actions, and blocks duplicate submissions', async () => {
  let complete!: () => void;
  jest.mocked(login).mockImplementation(
    () =>
      new Promise<void>((resolve) => {
        complete = resolve;
      }),
  );
  await render(<LoginScreen />);
  await fireEvent.changeText(
    screen.getByLabelText('E-posta'),
    'deniz@example.com',
  );
  await fireEvent.changeText(screen.getByLabelText('Şifre'), 'password');
  await fireEvent.press(screen.getByRole('button', { name: 'Giriş Yap' }));
  expect(
    screen.getByRole('button', { name: 'Giriş Yap' }).props.accessibilityState,
  ).toMatchObject({ disabled: true, busy: true });
  await fireEvent.press(screen.getByRole('button', { name: 'Giriş Yap' }));
  expect(login).toHaveBeenCalledTimes(1);
  await act(async () => {
    complete();
  });
  expect(mockReplace).toHaveBeenCalledWith('/account');
});
test('registration and password recovery preserve separate navigation actions', async () => {
  await render(<LoginScreen />);
  await fireEvent.press(
    screen.getByRole('button', { name: 'Yeni Hesap Oluştur' }),
  );
  await fireEvent.press(
    screen.getByRole('button', { name: 'Şifremi unuttum?' }),
  );
  expect(mockPush.mock.calls).toEqual([['/register'], ['/forgot-password']]);
});
test('password visibility has an accessible label and does not alter the password', async () => {
  await render(<LoginScreen />);
  await fireEvent.changeText(screen.getByLabelText('Şifre'), 'private');
  await fireEvent.press(screen.getByRole('button', { name: 'Şifreyi göster' }));
  expect(screen.getByLabelText('Şifre').props.secureTextEntry).toBe(false);
  expect(screen.getByLabelText('Şifre').props.value).toBe('private');
  expect(googleLogin).not.toHaveBeenCalled();
});
