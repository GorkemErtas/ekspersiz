import test from 'node:test';
import assert from 'node:assert/strict';
import branding from '../plugins/withAndroidBranding.cjs';

test('adaptive masks retain the existing foreground with idempotent internal padding', () => {
  const original =
    '<adaptive-icon><background android:drawable="@color/iconBackground"/><foreground android:drawable="@mipmap/ic_launcher_foreground"/></adaptive-icon>';
  const result = branding.insetForeground(original);
  assert.match(
    result,
    /<foreground><inset android:inset="22%" android:drawable="@mipmap\/ic_launcher_foreground" \/><\/foreground>/,
  );
  assert.ok(
    result.includes('<background android:drawable="@color/iconBackground"/>'),
  );
  assert.equal(branding.insetForeground(result), result);
  assert.throws(
    () => branding.insetForeground('<adaptive-icon/>'),
    /Unexpected/,
  );
});
