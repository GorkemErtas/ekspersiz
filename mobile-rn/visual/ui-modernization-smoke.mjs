// Native UI evidence only. Requires the explicit localhost fixture build, never production.
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { run, ui, nodes, waitFor, capture, pause } from './native-capture.mjs';

const app = 'com.gorkem.ekspersiz.dev';
assert.ok(
  process.env.ANDROID_SERIAL,
  'Choose the test device explicitly with ANDROID_SERIAL.',
);
assert.equal(
  run('shell', 'getprop', 'ro.kernel.qemu').trim(),
  '1',
  'The display matrix requires a dedicated emulator.',
);
const base = 'http://127.0.0.1:18080/api/v1';
const output = path.resolve('visual-artifacts/ui-modernization');
const evidence = [];
const layoutDetails = process.argv.includes('--layout-details');
const keyboardOnly = process.argv.includes('--keyboard-only');
assert.ok(
  !(layoutDetails && keyboardOnly),
  'Choose one smoke phase at a time.',
);
const apkPath = run('shell', 'pm', 'path', app)
  .trim()
  .split(/\r?\n/)
  .find((line) => line.endsWith('/base.apk'));
assert.ok(
  apkPath?.startsWith('package:'),
  'Install the dedicated fixture APK first.',
);
const apkSha256 = run(
  'shell',
  'sha256sum',
  apkPath.slice('package:'.length),
).split(/\s+/)[0];
assert.match(apkSha256, /^[0-9a-f]{64}$/);
let passed = false;
let geometry = { width: 390, height: 844 };
const fixture = async (route, method = 'GET', body) => {
  const response = await fetch(base + route, {
    method,
    headers: {
      Authorization: 'Bearer visual-only-token',
      'Content-Type': 'application/json',
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  assert.equal(response.ok, true, 'Fixture endpoint failed: ' + route);
  return response.json();
};
assert.equal((await fixture('/__fixture')).testOnly, true);
const initialEvents = (await fixture('/__fixture/events')).length;
await mkdir(output, { recursive: true });

function matches(node, text) {
  return node.text === text || node['content-desc'] === text;
}
async function tap(text, { input = false, partial = false } = {}) {
  const tree = nodes(await ui());
  const targets = tree.filter(
    (node) =>
      node.package === app &&
      node.area > 0 &&
      (matches(node, text) ||
        (partial &&
          (node.text?.includes(text) ||
            node['content-desc']?.includes(text)))) &&
      (input
        ? node.class === 'android.widget.EditText'
        : node.clickable === 'true' &&
          node.class !== 'android.widget.EditText'),
  );
  const node = targets.sort((a, b) => a.area - b.area)[0];
  assert.ok(node, 'Visible native control missing: ' + text);
  run(
    'shell',
    'input',
    'tap',
    String(Math.round(node.x)),
    String(Math.round(node.y)),
  );
  await pause(400);
}
async function scrollTo(text, { button = false } = {}) {
  for (let index = 0; index < 14; index++) {
    if (
      nodes(await ui()).some(
        (node) =>
          node.package === app &&
          node.area > 0 &&
          (!button ||
            (node.clickable === 'true' &&
              node.class !== 'android.widget.EditText')) &&
          (matches(node, text) || node['content-desc']?.includes(text)),
      )
    )
      return;
    run(
      'shell',
      'input',
      'swipe',
      String(Math.round(geometry.width * 0.6)),
      String(Math.round(geometry.height * 0.78)),
      String(Math.round(geometry.width * 0.6)),
      String(Math.round(geometry.height * 0.3)),
      '220',
    );
    await pause(200);
  }
  throw new Error('Scroll target missing: ' + text);
}
async function text(label, value) {
  await scrollTo(label);
  await tap(label, { input: true });
  run('shell', 'input', 'text', value);
}
async function shot(name, marker) {
  await capture('ui-' + name, marker, geometry);
  evidence.push({ name, marker, ...geometry });
}
async function assertKeyboard(name) {
  const windowState = run('shell', 'dumpsys', 'window');
  const frame = windowState.match(
    /type=ime frame=\[\d+,(\d+)\]\[\d+,\d+\][^\r\n]*\bvisible=true/,
  );
  assert.ok(frame, 'Keyboard is not visible: ' + name);
  const focused = nodes(await ui()).find(
    (node) =>
      node.package === app &&
      node.class === 'android.widget.EditText' &&
      node.focused === 'true',
  );
  assert.ok(focused?.area > 0, 'Focused field is not visible: ' + name);
  assert.ok(
    focused.bottom <= Number(frame[1]),
    'Keyboard covers focused field: ' + name,
  );
  evidence.push({
    name,
    inputBounds: focused.bounds,
    keyboardTop: Number(frame[1]),
  });
}
function route(value) {
  run(
    'shell',
    'am',
    'start',
    '-a',
    'android.intent.action.VIEW',
    '-d',
    "'ekspersiz-dev://" + value + "'",
    app,
  );
}
async function home() {
  route('main');
  await waitFor('Ana Sayfa');
  await tap('Ana Sayfa');
  await waitFor('AI Hasar Analizi');
}
async function restart() {
  run('shell', 'am', 'force-stop', app);
  run('shell', 'am', 'start', '-W', '-n', app + '/.MainActivity');
  await waitFor('Ana Sayfa');
}
async function theme(mode) {
  const current = await ui();
  const toggle = mode === 'light' ? 'Açık tema' : 'Koyu tema';
  if (current.includes(toggle)) await tap(toggle);
}
async function navigation(mode) {
  const overlay =
    mode === 'gesture'
      ? 'com.android.internal.systemui.navbar.gestural'
      : 'com.android.internal.systemui.navbar.threebutton';
  assert.ok(
    run('shell', 'cmd', 'overlay', 'list').includes(overlay),
    'Navigation overlay is unavailable',
  );
  run('shell', 'cmd', 'overlay', 'enable-exclusive', '--category', overlay);
  await pause(500);
}
async function assertAssistant(name) {
  const tree = nodes(await ui());
  const button = tree.find(
    (node) =>
      node.package === app &&
      node.clickable === 'true' &&
      node['content-desc']?.includes('AI Asistan’ı aç'),
  );
  assert.ok(button, 'Assistant is not visible/clickable');
  assert.ok(
    button.left >= 0 &&
      button.top >= 0 &&
      button.right <= geometry.width &&
      button.bottom <= geometry.height,
  );
  const tabs = tree.filter(
    (node) =>
      node.package === app &&
      node.clickable === 'true' &&
      ['Ana Sayfa', 'Araçlar', 'Analizler', 'Profil'].some((title) =>
        matches(node, title),
      ),
  );
  assert.ok(tabs.length >= 3, 'Navigation is not visible');
  for (const tab of tabs)
    assert.ok(
      button.right <= tab.left ||
        button.left >= tab.right ||
        button.bottom <= tab.top ||
        button.top >= tab.bottom,
      'Assistant overlaps navigation',
    );
  await shot(name, 'AI Hasar Analizi');
  await tap('AI Asistan’ı aç', { partial: true });
  await waitFor('Araç bağlamı');
  run('shell', 'input', 'keyevent', 'KEYCODE_BACK');
  await waitFor('AI Hasar Analizi');
  evidence.push({
    name: name + '-assistant-hit',
    button,
    navigation: tabs.map(({ left, top, right, bottom }) => ({
      left,
      top,
      right,
      bottom,
    })),
  });
}
async function assistantKeyboard() {
  route('assistant');
  await waitFor('Araç bağlamı');
  await text('Sorunuz', 'yerel%stest');
  await shot('assistant-keyboard', 'Araç bağlamı');
  await assertKeyboard('assistant-keyboard-bounds');
  run('shell', 'input', 'keyevent', 'KEYCODE_BACK');
}

async function smoke() {
  if (layoutDetails) {
    run('reverse', 'tcp:18080', 'tcp:18080');
    run('shell', 'wm', 'density', '160');
    run('shell', 'wm', 'size', '390x844');
    run('shell', 'wm', 'user-rotation', 'lock', '1');
    geometry = { width: 844, height: 390 };
    for (const mode of ['three-button', 'gesture']) {
      await navigation(mode);
      await restart();
      await home();
      assert.match(await ui(), /<hierarchy rotation="1">/);
      await theme(mode === 'gesture' ? 'dark' : 'light');
      await assertAssistant('rotation-90-' + mode);
      await tap('Profil');
      await shot('rotation-profile-' + mode, 'Deniz Yılmaz');
    }
    run('shell', 'wm', 'user-rotation', 'lock', '0');
    run('shell', 'wm', 'size', '320x640');
    run('shell', 'settings', 'put', 'system', 'font_scale', '1.6');
    geometry = { width: 320, height: 640 };
    await restart();
    route('vehicle/new');
    await shot('small-vehicle-form-font-16', 'Araç bilgileri');
    await scrollTo('Model yılı');
    await tap('Model yılı', { partial: true });
    await shot('small-year-options-font-16', 'Model yılı seçin');
    await text('Seçeneklerde ara', '2024');
    await shot('small-year-keyboard-font-16', '2024');
    await assertKeyboard('small-year-keyboard-bounds');
    evidence.push({ name: 'completed', physicalDevice: false });
    return;
  }
  run('reverse', 'tcp:18080', 'tcp:18080');
  run('shell', 'wm', 'density', '160');
  run('shell', 'wm', 'size', '390x844');
  run('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP');
  run('shell', 'wm', 'dismiss-keyguard');
  run('shell', 'am', 'force-stop', app);
  run('shell', 'am', 'start', '-W', '-n', app + '/.MainActivity');
  let tree = await ui();
  if (tree.includes('Atla')) await tap('Atla');
  await waitFor('Giriş Yap');
  await shot('login-logo', 'Giriş Yap');
  await text('E-posta', 'deniz@example.com');
  run('shell', 'input', 'keyevent', 'KEYCODE_BACK');
  await text('Şifre', 'FixtureOnly123');
  await shot('login-keyboard', 'Şifre');
  await assertKeyboard('login-keyboard-bounds');
  run('shell', 'input', 'keyevent', 'KEYCODE_BACK');
  await scrollTo('Giriş Yap');
  await tap('Giriş Yap');
  await waitFor('AI Hasar Analizi');
  assert.ok(
    (await fixture('/__fixture/events'))
      .slice(initialEvents)
      .some((event) => event.method === 'POST' && event.path === '/auth/login'),
    'Installed app did not authenticate against the localhost fixture',
  );
  if (keyboardOnly) {
    await assistantKeyboard();
    route('vehicle/new');
    await waitFor('Araç bilgileri');
    await scrollTo('Model yılı');
    await tap('Model yılı', { partial: true });
    await text('Seçeneklerde ara', '2024');
    await shot('vehicle-year-keyboard', '2024');
    await assertKeyboard('year-search-keyboard-bounds');
    evidence.push({ name: 'completed', physicalDevice: false });
    return;
  }

  for (const entry of [
    {
      name: 'small-dark-gesture',
      width: 320,
      height: 640,
      font: '1.0',
      mode: 'dark',
      navigation: 'gesture',
    },
    {
      name: 'small-light-large-font',
      width: 320,
      height: 640,
      font: '1.6',
      mode: 'light',
      navigation: 'three-button',
    },
    {
      name: 'standard-light-gesture',
      width: 390,
      height: 844,
      font: '1.0',
      mode: 'light',
      navigation: 'gesture',
    },
    {
      name: 'standard-dark-three-button',
      width: 390,
      height: 844,
      font: '1.0',
      mode: 'dark',
      navigation: 'three-button',
    },
    {
      name: 'standard-dark-font-2',
      width: 390,
      height: 844,
      font: '2.0',
      mode: 'dark',
      navigation: 'gesture',
    },
    {
      name: 'landscape-light',
      width: 844,
      height: 390,
      font: '1.0',
      mode: 'light',
      navigation: 'three-button',
    },
    {
      name: 'tablet-dark',
      width: 1024,
      height: 768,
      font: '1.0',
      mode: 'dark',
      navigation: 'gesture',
    },
    {
      name: 'tablet-light-large-font',
      width: 1024,
      height: 768,
      font: '1.6',
      mode: 'light',
      navigation: 'three-button',
    },
  ]) {
    geometry = { width: entry.width, height: entry.height };
    run('shell', 'wm', 'size', entry.width + 'x' + entry.height);
    run('shell', 'settings', 'put', 'system', 'font_scale', entry.font);
    await navigation(entry.navigation);
    await restart();
    await home();
    await theme(entry.mode);
    await assertAssistant(entry.name);
    evidence.push(entry);
  }

  geometry = { width: 390, height: 844 };
  run('shell', 'wm', 'size', '390x844');
  run('shell', 'settings', 'put', 'system', 'font_scale', '1.0');
  await restart();
  await home();
  await theme('dark');
  await tap('Araçlar');
  await shot('vehicles', 'Toyota');
  await tap('34ABC123 araç işlemleri');
  await shot('vehicle-actions', 'Düzenle');
  await tap('Kapat');
  await tap('Araç Ekle');
  await waitFor('Araç bilgileri');
  await text('Plaka', '34UI123');
  run('shell', 'input', 'keyevent', 'KEYCODE_BACK');
  for (const [title, value] of [
    ['Marka', 'Toyota'],
    ['Model', 'Corolla'],
  ]) {
    await scrollTo(title);
    await tap(title, { partial: true });
    await waitFor(title + ' seçin');
    if ((await ui()).includes('Seçeneklerde ara')) {
      await text('Seçeneklerde ara', value);
      run('shell', 'input', 'keyevent', 'KEYCODE_BACK');
    }
    await scrollTo(value, { button: true });
    await tap(value);
  }
  await scrollTo('Model yılı');
  await tap('Model yılı', { partial: true });
  await shot('vehicle-year-options', 'Model yılı seçin');
  await text('Seçeneklerde ara', '2024');
  await shot('vehicle-year-keyboard', '2024');
  await assertKeyboard('year-search-keyboard-bounds');
  await tap('2024');
  await scrollTo('Kaydet');
  await shot('vehicle-form-bottom', 'Kaydet');
  await tap('Kaydet');
  await pause(500);
  const created = (await fixture('/vehicles')).find(
    (vehicle) => vehicle.plate === '34UI123',
  );
  assert.equal(created?.modelYear, 2024);
  assert.equal(typeof created.modelYear, 'number');
  evidence.push({
    name: 'native-vehicle-create',
    numericModelYear: created.modelYear,
  });

  const legacy = await fixture('/vehicles', 'POST', {
    plate: '34LEGACY1',
    brand: 'Toyota',
    model: 'Corolla',
    modelYear: 1942,
    mileage: 1000,
    notes: '',
  });
  route('vehicle/new?edit=' + legacy.id);
  await waitFor('1942');
  await shot('vehicle-legacy-year', '1942');
  await scrollTo('Kaydet');
  await tap('Kaydet');
  assert.equal((await fixture('/vehicles/' + legacy.id)).modelYear, 1942);
  evidence.push({
    name: 'native-vehicle-legacy-preserved',
    numericModelYear: 1942,
  });

  for (const [routeName, marker] of [
    ['assistant', 'Araç bağlamı'],
    ['inspection/1', 'Hasar Analiz Raporu'],
    ['inspection/record?id=1', 'Beyan Tutanağı'],
    ['vehicle/1', 'Toyota'],
    ['vehicle/tracking?vehicle=1&kind=maintenance', 'Bakım'],
    ['billing', 'Paket'],
    ['notifications', 'Bildirimler'],
    ['business', 'Şirket Yönetimi'],
  ]) {
    route(routeName);
    await shot('screen-' + routeName.replaceAll(/[^a-z0-9]/gi, '-'), marker);
  }
  await assistantKeyboard();

  await home();
  await tap('Analizler');
  await shot('history', 'Analiz Geçmişi');
  await tap('Profil');
  await shot('profile', 'deniz@example.com');

  for (const scenario of [
    'empty',
    'error',
    'business-owner',
    'business-member',
  ]) {
    await fixture('/__fixture/scenario', 'POST', { scenario });
    await restart();
    await home();
    await shot(
      'state-' + scenario,
      scenario === 'empty'
        ? 'Garajınız henüz boş'
        : scenario === 'error'
          ? 'Görsel test:'
          : 'Hesap değiştir',
    );
    if (scenario.startsWith('business-')) {
      await tap('Hesap değiştir');
      await shot('workspace-' + scenario, 'Hesap Değiştir');
      await tap('Kapat');
      route('business');
      await shot('business-' + scenario, 'Şirket Yönetimi');
      if (scenario === 'business-member')
        assert.ok(!(await ui()).includes('Davet Gönder'));
    }
  }
  await fixture('/__fixture/scenario', 'POST', { scenario: 'default' });
  for (const name of [
    'window_animation_scale',
    'transition_animation_scale',
    'animator_duration_scale',
  ])
    run('shell', 'settings', 'put', 'global', name, '0');
  await restart();
  await home();
  await assertAssistant('reduced-motion');
  const log = run(
    'shell',
    'logcat',
    '-d',
    '--pid=' + run('shell', 'pidof', app).trim(),
  );
  assert.doesNotMatch(log, /FATAL EXCEPTION|Fatal signal/);
  evidence.push({
    name: 'completed',
    physicalDevice: false,
    api: run('shell', 'getprop', 'ro.build.version.sdk').trim(),
  });
}
try {
  await smoke();
  passed = true;
} finally {
  await writeFile(
    path.join(
      output,
      layoutDetails
        ? 'layout-details-results.json'
        : keyboardOnly
          ? 'keyboard-smoke-results.json'
          : 'ui-smoke-results.json',
    ),
    JSON.stringify(
      {
        passed,
        apkSha256,
        physicalDevice: false,
        testedAt: new Date().toISOString(),
        evidence,
      },
      null,
      2,
    ) + '\n',
  );
  run('shell', 'wm', 'size', 'reset');
  run('shell', 'wm', 'density', 'reset');
  if (layoutDetails) run('shell', 'wm', 'user-rotation', 'free');
  run('shell', 'settings', 'put', 'system', 'font_scale', '1.0');
  for (const name of [
    'window_animation_scale',
    'transition_animation_scale',
    'animator_duration_scale',
  ])
    run('shell', 'settings', 'put', 'global', name, '1');
}
