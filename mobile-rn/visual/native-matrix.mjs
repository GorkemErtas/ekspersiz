// Additional real native cases, with equivalent Flutter and RN device geometry.
import {
  run,
  flutterRoute,
  capture,
  tap,
  waitFor,
  pause,
} from './native-capture.mjs';
async function reactNativeMain() {
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
  await waitFor('AI Hasar Analizi', 120000, 'com.gorkem.ekspersiz.dev');
}
for (const entry of [
  { name: 'main-light', width: 390, height: 844, night: 'no', font: '1.0' },
  {
    name: 'main-tablet-dark',
    width: 1024,
    height: 768,
    night: 'yes',
    font: '1.0',
  },
]) {
  run('shell', 'wm', 'size', `${entry.width}x${entry.height}`);
  run('shell', 'wm', 'density', '160');
  run('shell', 'settings', 'put', 'system', 'font_scale', entry.font);
  run('shell', 'cmd', 'uimode', 'night', entry.night);
  await flutterRoute('main');
  await capture(`flutter-${entry.name}`, 'AI Hasar Analizi', entry);
  await reactNativeMain();
  const desired = entry.night === 'yes' ? 'Koyu tema' : 'Açık tema';
  const xml = await (await import('./native-capture.mjs')).ui();
  if (xml.includes(desired)) await tap(desired);
  await pause(500);
  await capture(`react-native-${entry.name}`, 'AI Hasar Analizi', entry);
}
run('shell', 'wm', 'size', '390x844');
run('shell', 'settings', 'put', 'system', 'font_scale', '1.0');
run('shell', 'cmd', 'uimode', 'night', 'yes');
