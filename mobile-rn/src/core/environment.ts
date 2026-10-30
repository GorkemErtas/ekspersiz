const productionApi =
  'https://ekspersiz-backend-production.up.railway.app/api/v1';

export function apiBaseUrl(value: string | undefined, variant: unknown) {
  if (variant === 'production' && value !== productionApi)
    throw new Error('Production API yapılandırması geçersiz.');
  return value ?? 'http://10.0.2.2:8080/api/v1';
}
