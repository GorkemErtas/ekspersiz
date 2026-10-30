import { webLink } from './links';
test.each(['https://example.com/report', 'http://localhost:8080/'])(
  'allows a normal web source: %s',
  (url) => expect(webLink(url)).toBe(url),
);
test.each([
  'javascript:alert(1)',
  'file:///private/report.pdf',
  'intent://payment',
  'https://user:secret@example.com/',
])('blocks executable, local and credential-bearing source links: %s', (url) =>
  expect(() => webLink(url)).toThrow(),
);
