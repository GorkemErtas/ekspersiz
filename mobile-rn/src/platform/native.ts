import { Platform } from 'react-native';
import type { NativeBridge } from '../../modules/ekspersiz-native';
export const native = () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports -- Keep custom native initialization off the auth render path.
  require('../../modules/ekspersiz-native').default as NativeBridge;
export async function welcomeCredits() {
  if (Platform.OS !== 'android')
    throw new Error('Bu cihazda başlangıç kredisi doğrulaması kullanılamıyor.');
  const { api, session } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports -- Runtime owns the session; resolve only on the explicit device-verification action.
    require('../core/runtime') as typeof import('../core/runtime');
  const { generation } = session.getSnapshot();
  const deviceId = await native().deviceId();
  session.check(generation);
  const challenge = await api.request<{
    available: boolean;
    message?: string;
    id: string;
    cloudProjectNumber: string;
    requestHash: string;
  }>('/credits/welcome/challenge', { method: 'POST', body: { deviceId } });
  if (!challenge.available)
    return challenge.message ?? 'Başlangıç kredisi şu anda kullanılamıyor.';
  const token = await native().integrityToken(
    String(challenge.cloudProjectNumber),
    challenge.requestHash,
  );
  session.check(generation);
  await api.request('/credits/welcome/claim', {
    method: 'POST',
    body: { challengeId: challenge.id, token },
  });
  return 'Cihaz doğrulaması tamamlandı. Uygun hesapların başlangıç kredileri tanımlandı.';
}
