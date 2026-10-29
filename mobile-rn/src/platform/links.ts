export function webLink(value: string) {
  const url = new URL(value);
  if (
    !['https:', 'http:'].includes(url.protocol) ||
    url.username ||
    url.password
  )
    throw new Error('Bağlantı açılamadı.');
  return url.href;
}
