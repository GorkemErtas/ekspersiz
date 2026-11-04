import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { once } from 'node:events';
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PNG } from 'pngjs';

const fixtureScript = fileURLToPath(
  new URL('../visual/fixture-server.mjs', import.meta.url),
);

test('saved references compare without Flutter and still enforce size and mismatch gates', () => {
  const directory = mkdtempSync(join(tmpdir(), 'ekspersiz-visual-'));
  try {
    const reference = join(directory, 'reference.png');
    const native = join(directory, 'native.png');
    const diff = join(directory, 'diff.png');
    const picture = new PNG({ width: 20, height: 20 });
    picture.data.fill(255);
    const bytes = PNG.sync.write(picture);
    writeFileSync(reference, bytes);
    writeFileSync(native, bytes);
    const compare = () =>
      spawnSync(
        process.execPath,
        [
          fileURLToPath(new URL('./compare-screenshots.mjs', import.meta.url)),
          reference,
          native,
          diff,
        ],
        { encoding: 'utf8', timeout: 10000 },
      );
    assert.equal(compare().status, 0);
    assert.equal(JSON.parse(readFileSync(diff + '.json', 'utf8')).fraction, 0);
    picture.data.fill(0);
    writeFileSync(native, PNG.sync.write(picture));
    assert.equal(compare().status, 1);
    assert.equal(
      JSON.parse(readFileSync(diff + '.json', 'utf8')).passed,
      false,
    );
    writeFileSync(native, PNG.sync.write(new PNG({ width: 10, height: 10 })));
    const result = compare();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Equivalent viewport required/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('RN smoke fixture serves synthetic data on loopback and rejects production', async () => {
  const production = spawnSync(process.execPath, [fixtureScript], {
    env: { ...process.env, NODE_ENV: 'production' },
    encoding: 'utf8',
    timeout: 10000,
  });
  assert.equal(production.status, 1);
  assert.match(production.stderr, /cannot run in production/);
  const child = spawn(process.execPath, [fixtureScript], {
    env: { ...process.env, NODE_ENV: 'test', UI_FIXTURE_PORT: '0' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const exited = once(child, 'exit');
  let errors = '';
  child.stderr.on('data', (chunk) => {
    errors += chunk;
  });
  try {
    const [startup] = await Promise.race([
      once(child.stdout, 'data'),
      exited.then(() => {
        throw new Error('Fixture exited before startup: ' + errors);
      }),
      new Promise((_, reject) => {
        const timer = setTimeout(
          () => reject(new Error('Fixture startup timed out')),
          10000,
        );
        timer.unref();
      }),
    ]);
    const port = startup.toString().match(/127\.0\.0\.1:(\d+)/)?.[1];
    assert.ok(port, 'Fixture did not report its loopback port');
    const base = `http://127.0.0.1:${port}/api/v1`;
    const response = await fetch(base + '/__fixture');
    assert.equal(response.ok, true);
    assert.equal((await response.json()).testOnly, true);
    const login = await fetch(base + '/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'deniz@example.com',
        password: 'FixtureOnly123',
      }),
    });
    assert.equal(login.ok, true);
    const headers = { Authorization: 'Bearer visual-only-token' };
    assert.equal((await fetch(base + '/vehicles')).status, 401);
    const vehicles = await fetch(base + '/vehicles', { headers });
    assert.equal(vehicles.ok, true);
    assert.equal((await vehicles.json())[0].brand, 'Toyota');
    const unsupported = await fetch(base + '/unknown-route', { headers });
    assert.equal(unsupported.status, 404);
  } finally {
    child.kill();
    await exited;
  }
});
