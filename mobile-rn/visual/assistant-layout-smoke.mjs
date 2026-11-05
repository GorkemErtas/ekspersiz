// Run only against the explicit loopback fixture preview on a dedicated emulator.
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

assert.ok(
  process.env.ANDROID_SERIAL,
  'Choose the dedicated emulator with ANDROID_SERIAL.',
);
const output = path.resolve('visual-artifacts/ui-refresh');
process.env.UI_CAPTURE_ARTIFACT_DIR = output;
process.env.UI_CAPTURE_OUTPUT_DIR = path.join(output, 'captures');
const { run, ui, nodes, waitFor, capture, pause } =
  await import('./native-capture.mjs');
const app = 'com.gorkem.ekspersiz.dev';
assert.equal(run('shell', 'getprop', 'ro.kernel.qemu').trim(), '1');
const installedApk = run('shell', 'pm', 'path', app)
  .trim()
  .split(/\r?\n/)
  .find((line) => line.endsWith('/base.apk'));
assert.ok(
  installedApk?.startsWith('package:'),
  'Install the fixture-only preview first.',
);
const apkSha256 = run(
  'shell',
  'sha256sum',
  installedApk.slice('package:'.length),
).split(/\s+/)[0];
const base = 'http://127.0.0.1:18080/api/v1';
assert.equal((await (await fetch(base + '/__fixture')).json()).testOnly, true);
const originalFont = run(
  'shell',
  'settings',
  'get',
  'system',
  'font_scale',
).trim();
const originalSize =
  run('shell', 'wm', 'size').match(/Override size: (\d+x\d+)/)?.[1] ?? 'reset';
const originalDensity =
  run('shell', 'wm', 'density').match(/Override density: (\d+)/)?.[1] ??
  'reset';
const originalNavigation = run('shell', 'cmd', 'overlay', 'list').match(
  /\[x\] (com\.android\.internal\.systemui\.navbar\.\S+)/,
)?.[1];
const evidence = [];
let geometry = { width: 390, height: 844 };
let passed = false;

const visible = (tree, label) =>
  tree.find(
    (node) =>
      node.package === app &&
      node.area > 0 &&
      (node['content-desc'] === label || node.text === label),
  );
async function tap(label, input = false) {
  const target = nodes(await ui())
    .filter(
      (node) =>
        node.package === app &&
        node.area > 0 &&
        (node['content-desc'] === label || node.text === label) &&
        (input
          ? node.class === 'android.widget.EditText'
          : node.clickable === 'true'),
    )
    .sort((a, b) => a.area - b.area)[0];
  assert.ok(target, 'Missing native control: ' + label);
  run(
    'shell',
    'input',
    'tap',
    String(Math.round(target.x)),
    String(Math.round(target.y)),
  );
  await pause(300);
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
async function launch() {
  run('shell', 'am', 'force-stop', app);
  run('shell', 'am', 'start', '-W', '-n', app + '/.MainActivity');
  await waitFor('Ana Sayfa', 45000, app);
  await tap('Ana Sayfa');
  await waitFor('AI Asistan’ı aç', 30000, app);
}
async function shot(name, marker) {
  await capture(name, marker, geometry);
}
async function swipe(x, bottom, top = 140) {
  run(
    'shell',
    'input',
    'swipe',
    String(x),
    String(bottom),
    String(x),
    String(top),
    '240',
  );
  await pause(300);
}

await mkdir(output, { recursive: true });
try {
  run('reverse', 'tcp:18080', 'tcp:18080');
  run('shell', 'wm', 'density', '160');
  run('shell', 'wm', 'size', '390x844');
  run('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP');
  run('shell', 'wm', 'dismiss-keyguard');
  run('shell', 'am', 'start', '-W', '-n', app + '/.MainActivity');
  await waitFor(/Atla|Giriş Yap|Ana Sayfa/, 45000, app);
  if ((await ui()).includes('Atla')) await tap('Atla');
  if ((await ui()).includes('Giriş Yap')) {
    for (const [label, value] of [
      ['E-posta', 'deniz@example.com'],
      ['Şifre', 'FixtureOnly123'],
    ]) {
      await tap(label, true);
      run('shell', 'input', 'text', value);
      run('shell', 'input', 'keyevent', 'KEYCODE_BACK');
    }
    await tap('Giriş Yap');
  }
  await waitFor('AI Asistan’ı aç', 45000, app);

  for (const entry of [
    {
      name: 'small-dark',
      width: 320,
      height: 640,
      font: 1,
      mode: 'dark',
      navigation: 'gestural',
    },
    {
      name: 'small-light-large-text',
      width: 320,
      height: 640,
      font: 1.6,
      mode: 'light',
      navigation: 'threebutton',
    },
    {
      name: 'phone-dark',
      width: 390,
      height: 844,
      font: 1,
      mode: 'dark',
      navigation: 'threebutton',
    },
    {
      name: 'phone-dark-text-2',
      width: 390,
      height: 844,
      font: 2,
      mode: 'dark',
      navigation: 'gestural',
    },
    {
      name: 'large-light',
      width: 430,
      height: 932,
      font: 1,
      mode: 'light',
      navigation: 'gestural',
    },
    {
      name: 'landscape-dark',
      width: 844,
      height: 390,
      font: 1,
      mode: 'dark',
      navigation: 'threebutton',
    },
  ]) {
    geometry = { width: entry.width, height: entry.height };
    run('shell', 'wm', 'size', `${entry.width}x${entry.height}`);
    run('shell', 'settings', 'put', 'system', 'font_scale', String(entry.font));
    run(
      'shell',
      'cmd',
      'overlay',
      'enable-exclusive',
      '--category',
      'com.android.internal.systemui.navbar.' + entry.navigation,
    );
    await launch();
    const toggle = entry.mode === 'dark' ? 'Koyu tema' : 'Açık tema';
    if ((await ui()).includes(toggle)) await tap(toggle);
    let tree = nodes(await ui());
    const assistant = visible(tree, 'AI Asistan’ı aç');
    assert.ok(
      assistant?.area > 0 &&
        assistant.left >= 0 &&
        assistant.right <= entry.width &&
        assistant.bottom <= entry.height,
    );
    if (entry.font === 1)
      assert.ok(
        assistant.bottom - assistant.top >= 48 &&
          assistant.bottom - assistant.top <= 52,
        'Pill is not compact',
      );
    const tabs = ['Ana Sayfa', 'Araçlar', 'Analizler', 'Profil'].map((title) =>
      visible(tree, title),
    );
    for (const tab of tabs) {
      assert.ok(tab, 'Missing navigation tab');
      assert.ok(
        assistant.right <= tab.left ||
          assistant.left >= tab.right ||
          assistant.bottom <= tab.top ||
          assistant.top >= tab.bottom,
        'Assistant overlaps navigation',
      );
    }
    if (entry.width / entry.font < 240) {
      assert.ok(
        tabs[0].top === tabs[1].top && tabs[2].top >= tabs[0].bottom,
        'Large text navigation does not have room for full labels',
      );
    }
    const scroll = tree.find(
      (node) =>
        node.package === app &&
        node.scrollable === 'true' &&
        node.class === 'android.widget.ScrollView' &&
        node.left <= assistant.left &&
        node.right >= assistant.right,
    );
    assert.ok(
      scroll && scroll.bottom > assistant.top,
      'A full-width assistant dock still shortens the scroll viewport',
    );
    await shot(entry.name, 'AI Asistan’ı aç');
    // A swipe beside the pill must reach the underlying scroll view.
    const before = visible(tree, 'Yeni Analiz Başlat');
    await swipe(Math.max(scroll.left + 8, 24), Math.round(assistant.y));
    tree = nodes(await ui());
    const after = visible(tree, 'Yeni Analiz Başlat');
    assert.ok(
      !after || after.top !== before?.top,
      'Assistant wrapper intercepted the underlying scroll gesture',
    );
    for (let index = 0; index < 7; index++)
      await swipe(Math.round(scroll.x), Math.round(assistant.top - 12));
    const last = visible(nodes(await ui()), 'Son analizi aç');
    assert.ok(
      last && last.bottom <= assistant.top,
      'Final card cannot scroll clear of the floating assistant',
    );
    await shot(entry.name + '-scroll-end', 'Son analizi aç');
    await tap('AI Asistan’ı aç');
    await waitFor('Sorunuz', 30000, app);
    assert.equal(visible(nodes(await ui()), 'Gönder')?.enabled, 'false');
    await shot(entry.name + '-assistant', 'Sorunuz');
    evidence.push({
      ...entry,
      assistant: assistant.bounds,
      scroll: scroll.bounds,
      lastCard: last.bounds,
      tabs: tabs.map((tab) => tab.bounds),
    });
  }

  run('shell', 'wm', 'size', '390x844');
  run('shell', 'settings', 'put', 'system', 'font_scale', '1');
  geometry = { width: 390, height: 844 };
  await launch();
  await tap('AI Asistan’ı aç');
  await waitFor('Sorunuz', 30000, app);
  await tap('Sorunuz', true);
  run('shell', 'input', 'text', 'Bakim%szamani');
  await pause(500);
  const frame = run('shell', 'dumpsys', 'window').match(
    /type=ime frame=\[\d+,(\d+)\]\[\d+,\d+\][^\r\n]*\bvisible=true/,
  );
  const input = nodes(await ui()).find(
    (node) =>
      node.package === app &&
      node.class === 'android.widget.EditText' &&
      node.focused === 'true',
  );
  assert.ok(
    frame && input?.area > 0 && input.bottom <= Number(frame[1]),
    'Keyboard covers the composer',
  );
  await shot('assistant-keyboard', 'Sorunuz');
  evidence.push({
    name: 'keyboard',
    input: input.bounds,
    keyboardTop: Number(frame[1]),
  });
  run('shell', 'input', 'keyevent', 'KEYCODE_BACK');
  await launch();
  for (const [tab, marker] of [
    ['Araçlar', 'Garajınız'],
    ['Analizler', 'Analiz Geçmişi'],
    ['Profil', 'deniz@example.com'],
  ]) {
    await tap(tab);
    await shot('tab-' + tab, marker);
    assert.ok(
      !visible(nodes(await ui()), 'AI Asistan’ı aç'),
      'Home-only assistant leaked into another tab',
    );
  }
  for (const [name, marker] of [
    ['vehicle/new', 'Araç bilgileri'],
    ['inspection/1', 'Hasar Analiz Raporu'],
    ['notifications', 'Bildirimler'],
    ['billing', 'Paket'],
  ]) {
    route(name);
    await shot('screen-' + name.replaceAll('/', '-'), marker);
  }
  const events = await (await fetch(base + '/__fixture/events')).json();
  assert.ok(
    events.some((event) => event.path === '/vehicles'),
    'Preview did not use the fixture',
  );
  assert.equal(
    events.filter((event) => event.path === '/ai-assistant/chat').length,
    0,
    'Layout validation sent an AI request',
  );
  const log = run(
    'shell',
    'logcat',
    '-d',
    '--pid=' + run('shell', 'pidof', app).trim(),
  );
  assert.doesNotMatch(log, /FATAL EXCEPTION|Fatal signal/);
  passed = true;
} finally {
  await writeFile(
    path.join(output, 'results.json'),
    JSON.stringify(
      {
        passed,
        apkSha256,
        fixtureOnly: true,
        jsPreviewOnExistingNativeShell: true,
        testedAt: new Date().toISOString(),
        evidence,
      },
      null,
      2,
    ) + '\n',
  );
  run('shell', 'wm', 'size', originalSize);
  run('shell', 'wm', 'density', originalDensity);
  run('shell', 'settings', 'put', 'system', 'font_scale', originalFont);
  if (originalNavigation)
    run(
      'shell',
      'cmd',
      'overlay',
      'enable-exclusive',
      '--category',
      originalNavigation,
    );
}
console.log(
  'Assistant layout, touch passthrough, scroll clearance, navigation and keyboard checks passed.',
);
