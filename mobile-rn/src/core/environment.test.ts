import { apiBaseUrl } from './environment';

test('production never falls back to a development or unexpected backend', () => {
  for (const value of [
    undefined,
    '',
    'http://10.0.2.2:8080/api/v1',
    'https://example.com/api/v1',
  ])
    expect(() => apiBaseUrl(value, 'production')).toThrow('Production API');
  const production =
    'https://ekspersiz-backend-production.up.railway.app/api/v1';
  expect(apiBaseUrl(production, 'production')).toBe(production);
  expect(apiBaseUrl(undefined, 'development')).toBe(
    'http://10.0.2.2:8080/api/v1',
  );
});
