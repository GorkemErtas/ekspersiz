import test from 'node:test';
import assert from 'node:assert/strict';
import { Buffer } from 'node:buffer';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkConstructorRules } from './check-android-r8.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const rules = [
  '-keep class * extends androidx.room.RoomDatabase { <init>(); }',
  '-keep class * extends androidx.work.InputMerger { <init>(); }',
].join('\n');

test('R8 guard rejects the old class-only rules, missing rules and broad member rules', () => {
  checkConstructorRules(rules);
  for (const broken of [
    rules.replaceAll(' { <init>(); }', ''),
    rules.split('\n')[0],
    rules.replace('<init>();', '*;'),
    rules.replace('<init>()', '<init>(int)'),
    rules.replaceAll('-keep', '# -keep'),
  ])
    assert.throws(() => checkConstructorRules(broken), /constructor keep rule/);
});

// Minimal DEX tables/class_data, including method references that are deliberately
// NOT definitions. This catches a verifier that merely searches for '<init>'.
function dexFixture({ brokenClass = -1, fault } = {}) {
  const names = [
    'Landroidx/work/impl/WorkDatabase_Impl;',
    'Landroidx/work/OverwritingInputMerger;',
    'Landroidx/work/ArrayCreatingInputMerger;',
    'V',
    '<init>',
    'I',
  ];
  const buffer = Buffer.alloc(2048);
  buffer.write('dex\n037\0', 0, 'ascii');
  const int = (at, value) => buffer.writeUInt32LE(value, at);
  int(36, 112);
  int(40, 0x12345678);
  int(56, names.length);
  int(60, 112);
  int(64, 5);
  int(68, 136);
  for (const [i, stringIndex] of [0, 1, 2, 3, 5].entries())
    int(136 + 4 * i, stringIndex);
  int(72, 2);
  int(76, 156);
  int(156 + 4, 3); // ()V
  int(168 + 4, 3);
  int(168 + 8, 320); // (I)V
  int(320, 1);
  buffer.writeUInt16LE(4, 324);
  int(88, 3);
  int(92, 180);
  int(96, 3);
  int(100, 204);
  let cursor = 328;
  for (const [i, value] of names.entries()) {
    int(112 + 4 * i, cursor);
    buffer[cursor++] = value.length;
    cursor += buffer.write(value, cursor, 'ascii');
    buffer[cursor++] = 0;
  }
  const uleb = (value) => {
    do {
      const part = value & 127;
      value >>>= 7;
      buffer[cursor++] = part | (value ? 128 : 0);
    } while (value);
  };
  for (let i = 0; i < 3; i++) {
    const broken = i === brokenClass;
    const method = 180 + 8 * i;
    buffer.writeUInt16LE(i, method);
    buffer.writeUInt16LE(broken && fault === 'arguments' ? 1 : 0, method + 2);
    int(method + 4, 4);
    const definition = 204 + 32 * i;
    int(definition, i);
    int(definition + 4, 0x11);
    int(definition + 8, 3);
    int(definition + 24, broken && fault === 'no-data' ? 0 : cursor);
    uleb(0);
    uleb(0);
    uleb(broken && fault === 'reference-only' ? 0 : 1);
    uleb(0);
    uleb(i);
    uleb(broken && fault === 'private' ? 0x10002 : 0x10001);
    uleb(broken && fault === 'no-code' ? 0 : 300);
  }
  // A minimal return-void code item, outside the metadata tables.
  buffer.writeUInt16LE(1, 300 + 6);
  int(300 + 12, 1);
  buffer.writeUInt16LE(0x0e, 300 + 16);
  int(32, cursor);
  return buffer.subarray(0, cursor);
}

test('compiled DEX guard requires public defined no-arg constructors in all three classes', () => {
  const directory = mkdtempSync(join(tmpdir(), 'ekspersiz-dex-'));
  const java = process.env.JAVA_HOME
    ? join(
        process.env.JAVA_HOME,
        'bin',
        process.platform === 'win32' ? 'java.exe' : 'java',
      )
    : 'java';
  const verify = (bytes) => {
    const path = join(directory, 'fixture.dex');
    writeFileSync(path, bytes);
    const result = spawnSync(
      java,
      [
        join(root, 'scripts/android/ReleaseIdentity.java'),
        'constructors',
        path,
      ],
      {
        encoding: 'utf8',
        timeout: 30_000,
      },
    );
    assert.ifError(result.error);
    return result;
  };
  try {
    const valid = verify(dexFixture());
    assert.equal(valid.status, 0, valid.stderr);
    assert.equal(JSON.parse(valid.stdout).classes.length, 3);
    for (let brokenClass = 0; brokenClass < 3; brokenClass++) {
      const result = verify(
        dexFixture({ brokenClass, fault: 'reference-only' }),
      );
      assert.equal(result.status, 1);
      assert.match(result.stderr, /missing public no-arg DEX constructor/);
    }
    for (const fault of ['arguments', 'private', 'no-data', 'no-code']) {
      const result = verify(dexFixture({ brokenClass: 0, fault }));
      assert.equal(result.status, 1, fault);
      assert.match(result.stderr, /missing public no-arg DEX constructor/);
    }
    assert.equal(verify(dexFixture().subarray(0, 80)).status, 1);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
