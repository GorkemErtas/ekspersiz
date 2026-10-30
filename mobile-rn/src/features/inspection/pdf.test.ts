import { readFileSync } from 'node:fs';
import { PDFDocument } from 'pdf-lib';
import * as Crypto from 'expo-crypto';
import fixture from '../../../visual/fixtures.json';
import type { DamageRecord, Inspection } from '../../core/models';
import {
  buildPdf,
  recordBlocks,
  recordSnapshot,
  reportBlocks,
  sharePdf,
} from './pdf';
jest.mock('../../platform/images', () => ({
  protectedImage: jest.fn(),
  removePrepared: jest.fn(),
}));
const inspection = fixture.inspection as Inspection;
const record: DamageRecord = {
  id: 1,
  inspectionId: 1,
  recordNumber: 'EXP-1',
  status: 'FINALIZED',
  documentVersion: 1,
  incidentDateTime: '2026-01-01T10:00:00',
  incidentCity: 'MUTABLE CITY',
  incidentDescription: 'MUTABLE TEXT',
  declarantFullName: 'MUTABLE NAME',
  snapshotJson: JSON.stringify({
    vehicle: { plate: 'IMMUTABLE-PLATE', brand: 'Toyota', model: 'Corolla' },
    analysis: { inspectionId: 1, damageSeverity: 'MINOR' },
    incidentCity: 'SNAPSHOT CITY',
    incidentDescription: 'SNAPSHOT DECLARATION',
    declarantFullName: 'SNAPSHOT NAME',
  }),
};
test('finalized document text comes from its immutable snapshot', () => {
  const blocks = JSON.stringify(recordBlocks(record));
  expect(blocks).toContain('SNAPSHOT DECLARATION');
  expect(blocks).toContain('IMMUTABLE-PLATE');
  expect(blocks).not.toContain('MUTABLE TEXT');
  expect(blocks).not.toContain('MUTABLE NAME');
});
test('draft, malformed snapshot and unfinished reports cannot be exported', () => {
  expect(() => recordSnapshot({ ...record, status: 'DRAFT' })).toThrow();
  expect(() => recordSnapshot({ ...record, snapshotJson: '[]' })).toThrow();
  expect(() => reportBlocks({ ...inspection, status: 'PENDING' })).toThrow();
});

test('sharing refuses a mismatched inspection or a finalized record without its server checksum', async () => {
  await expect(sharePdf({ ...inspection, id: 2 }, record)).rejects.toThrow(
    'kimlikleri',
  );
  await expect(sharePdf(inspection, record)).rejects.toThrow('doğrulanamadı');
  await expect(
    sharePdf(inspection, { ...record, contentHash: 'bad-hash' }),
  ).rejects.toThrow('doğrulanamadı');
});

test('a modified finalized snapshot is rejected before image loading or file sharing', async () => {
  const digest = jest
    .spyOn(Crypto, 'digestStringAsync')
    .mockResolvedValueOnce('0'.repeat(64));
  try {
    await expect(
      sharePdf(inspection, { ...record, contentHash: '1'.repeat(64) }),
    ).rejects.toThrow('doğrulanamadı');
    expect(digest).toHaveBeenCalledWith(
      Crypto.CryptoDigestAlgorithm.SHA256,
      record.snapshotJson,
    );
  } finally {
    digest.mockRestore();
  }
});
test('real PDF builder embeds original Turkish fonts and paginates long text on A4', async () => {
  const bytes = (name: string) =>
    new Uint8Array(readFileSync(`${process.cwd()}/assets/${name}`));
  const png = bytes('images/ekspersiz_logo.png');
  const pdf = await buildPdf(
    [
      {
        type: 'text',
        text: 'İstanbul — Çizik, göçük ve görünür hasar raporu',
        size: 22,
        bold: true,
      },
      ...Array.from({ length: 100 }, () => ({
        type: 'text' as const,
        text: 'Ön çamurluk, sürücü kapısı ve değişim değerlendirmesi. '.repeat(
          3,
        ),
      })),
    ],
    {
      regular: bytes('fonts/Roboto-Regular.ttf'),
      bold: bytes('fonts/Roboto-Bold.ttf'),
      logo: png,
      photo: png,
    },
  );
  const parsed = await PDFDocument.load(pdf);
  expect(parsed.getPageCount()).toBeGreaterThan(2);
  for (const page of parsed.getPages()) {
    expect(page.getWidth()).toBeCloseTo(595.28);
    expect(page.getHeight()).toBeCloseTo(841.89);
  }
  expect(parsed.getCreator()).toBe('EksperSiz');
});
