// Uses actual native screens. The separate fixture server is an explicit test transport only.
import { spawnSync } from 'node:child_process';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { PNG } from 'pngjs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const adb = path.join(
  process.env.ANDROID_HOME ??
    path.join(process.env.LOCALAPPDATA, 'Android', 'Sdk'),
  'platform-tools',
  process.platform === 'win32' ? 'adb.exe' : 'adb',
);
const serial = process.env.ANDROID_SERIAL ?? 'emulator-5554',
  artifact =
    process.env.UI_CAPTURE_ARTIFACT_DIR ??
    fileURLToPath(new URL('../visual-artifacts/', import.meta.url)),
  output =
    process.env.UI_CAPTURE_OUTPUT_DIR ??
    fileURLToPath(new URL('../../docs/migration/native/', import.meta.url));
export const run = (...args) => {
  const result = spawnSync(adb, ['-s', serial, ...args], {
    encoding: 'utf8',
    timeout: 20_000,
    windowsHide: true,
  });
  if (result.status !== 0)
    throw new Error(
      `ADB failed: ${args.slice(0, 3).join(' ')}: ${result.stderr || result.stdout}`,
    );
  return result.stdout;
};
export const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
export async function ui() {
  await mkdir(artifact, { recursive: true });
  run('shell', 'uiautomator', 'dump', '/sdcard/ekspersiz-capture.xml');
  run(
    'pull',
    '/sdcard/ekspersiz-capture.xml',
    path.join(artifact, 'capture.xml'),
  );
  return readFile(path.join(artifact, 'capture.xml'), 'utf8');
}
export function nodes(xml) {
  return [...xml.matchAll(/<node\b[^>]+>/g)]
    .map((match) =>
      Object.fromEntries(
        [...match[0].matchAll(/([\w-]+)="([^"]*)"/g)].map(([, key, value]) => [
          key,
          value.replaceAll('&amp;', '&').replaceAll('&quot;', '"'),
        ]),
      ),
    )
    .map((node) => {
      const rect = node.bounds?.match(/-?\d+/g)?.map(Number) ?? [];
      return {
        ...node,
        left: rect[0] ?? 0,
        top: rect[1] ?? 0,
        right: rect[2] ?? 0,
        bottom: rect[3] ?? 0,
        x: ((rect[0] ?? 0) + (rect[2] ?? 0)) / 2,
        y: ((rect[1] ?? 0) + (rect[3] ?? 0)) / 2,
        area:
          ((rect[2] ?? 0) - (rect[0] ?? 0)) * ((rect[3] ?? 0) - (rect[1] ?? 0)),
      };
    });
}
export async function waitFor(marker, timeout = 120_000, packageName) {
  const until = Date.now() + timeout;
  let xml = '';
  while (Date.now() < until) {
    xml = await ui();
    if (
      (typeof marker === 'string' ? xml.includes(marker) : marker.test(xml)) &&
      (!packageName ||
        nodes(xml).some(
          (node) =>
            node.package === packageName &&
            (typeof marker === 'string'
              ? node.text?.includes(marker) ||
                node['content-desc']?.includes(marker)
              : marker.test(`${node.text} ${node['content-desc']}`)),
        ))
    )
      return xml;
    await pause(300);
  }
  throw new Error(`Native screen did not show: ${marker}`);
}
export async function tap(marker, { bottom = false, input = false } = {}) {
  const xml = await waitFor(marker);
  const candidates = nodes(xml)
    .filter(
      (node) =>
        node.area > 0 &&
        (node.text?.includes(marker) ||
          node['content-desc']?.includes(marker)) &&
        (!bottom || node.y > 700) &&
        (!input || node.class === 'android.widget.EditText'),
    )
    .sort((a, b) => a.area - b.area);
  const target = candidates[0];
  if (!target) throw new Error(`Native control unavailable: ${marker}`);
  run(
    'shell',
    'input',
    'tap',
    String(Math.round(target.x)),
    String(Math.round(target.y)),
  );
  await pause(600);
}
export async function capture(
  name,
  marker,
  { width = 390, height = 844 } = {},
) {
  await mkdir(output, { recursive: true });
  await waitFor(
    marker,
    120000,
    name.startsWith('flutter-')
      ? 'com.gorkem.ekspersiz'
      : 'com.gorkem.ekspersiz.dev',
  );
  await pause(1200);
  run('shell', 'screencap', '-p', '/sdcard/ekspersiz-capture.png');
  const file = path.join(output, `${name}.png`);
  run('pull', '/sdcard/ekspersiz-capture.png', file);
  await writeFile(path.join(output, name + '.xml'), await ui(), 'utf8');
  const bytes = await readFile(file);
  const png = PNG.sync.read(bytes);
  let black = 0;
  for (let i = 0; i < png.data.length; i += 4)
    if (png.data[i] < 2 && png.data[i + 1] < 2 && png.data[i + 2] < 2) black++;
  if (black / (png.width * png.height) > 0.7)
    throw new Error(
      'Capture is a splash/loading surface, not the requested app screen.',
    );
  if (bytes.readUInt32BE(16) !== width || bytes.readUInt32BE(20) !== height)
    throw new Error(`Capture is not ${width}×${height}`);
  console.log(`Verified capture: ${name} (${marker})`);
}
export async function flutterRoute(route) {
  run('shell', 'am', 'force-stop', 'com.gorkem.ekspersiz');
  run(
    'shell',
    'am',
    'start',
    '-n',
    'com.gorkem.ekspersiz/.MainActivity',
    '--es',
    'route',
    `/${route}`,
    '--ez',
    'enable-software-rendering',
    'true',
    '--ez',
    'enable-impeller',
    'false',
  );
  await pause(2500);
}
async function nativeCaptures(mode) {
  run('reverse', 'tcp:18080', 'tcp:18080');
  run('reverse', 'tcp:8081', 'tcp:8081');
  run('shell', 'wm', 'size', '390x844');
  run('shell', 'wm', 'density', '160');
  run('shell', 'cmd', 'uimode', 'night', 'yes');
  if (mode === 'flutter') {
    await flutterRoute('main');
    await capture('flutter-main-dark', 'AI Hasar Analizi');
    await tap('Araçlar', { bottom: true });
    await capture('flutter-vehicles-dark', 'Toyota');
    await tap('Analizler', { bottom: true });
    await capture('flutter-history-dark', 'Analiz');
    await tap('Profil', { bottom: true });
    await capture('flutter-profile-dark', 'deniz@example.com');
    await flutterRoute('guide');
    await capture('flutter-guide-dark', 'Aracını tanı.');
    await flutterRoute('result');
    await capture('flutter-result-dark', 'Hasar Analiz Raporu');
  } else {
    run('shell', 'am', 'force-stop', 'com.gorkem.ekspersiz.dev');
    run(
      'shell',
      'am',
      'start',
      '-a',
      'android.intent.action.VIEW',
      '-d',
      "'exp+ekspersiz-mobile://expo-development-client/?disableFab=1&url=http%3A%2F%2F127.0.0.1%3A8081'",
      'com.gorkem.ekspersiz.dev',
    );
    await pause(4000);
    let xml = await waitFor(
      /AI Hasar Analizi|Tekrar hoş|Atla/,
      120000,
      'com.gorkem.ekspersiz.dev',
    );
    if (xml.includes('Atla')) await tap('Atla');
    xml = await ui();
    if (xml.includes('Tekrar hoş')) {
      await tap('E-posta', { input: true });
      run('shell', 'input', 'text', 'deniz@example.com');
      await tap('Şifre', { input: true });
      run('shell', 'input', 'text', 'FixtureOnly123');
      run('shell', 'input', 'keyevent', '4');
      await pause(400);
      await tap('Giriş Yap');
    }
    await capture('react-native-main-dark', 'AI Hasar Analizi');
    await tap('Araçlar', { bottom: true });
    await capture('react-native-vehicles-dark', 'Toyota');
    await tap('Analizler', { bottom: true });
    await capture('react-native-history-dark', 'Analiz Geçmişi');
    await tap('Profil', { bottom: true });
    await capture('react-native-profile-dark', 'deniz@example.com');
    run(
      'shell',
      'am',
      'start',
      '-a',
      'android.intent.action.VIEW',
      '-d',
      'ekspersiz-dev://guide',
      'com.gorkem.ekspersiz.dev',
    );
    await capture('react-native-guide-dark', 'Aracını tanı.');
    run(
      'shell',
      'am',
      'start',
      '-a',
      'android.intent.action.VIEW',
      '-d',
      'ekspersiz-dev://inspection/1',
      'com.gorkem.ekspersiz.dev',
    );
    await capture('react-native-result-dark', 'Hasar Analiz Raporu');
  }
}
if (['rn', 'flutter'].includes(process.argv[2]))
  await nativeCaptures(process.argv[2]);
