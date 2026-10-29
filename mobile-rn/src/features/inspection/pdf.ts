import {
  PDFDocument,
  PDFFont,
  StandardFonts,
  rgb,
  type PDFPage,
} from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import { Asset } from 'expo-asset';
import { Directory, File, Paths } from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import * as Crypto from 'expo-crypto';
import type { DamageRecord, Inspection } from '../../core/models';
import { isRecord } from '../../core/contracts';
import { dateText, label, number } from '../../core/labels';
import { session } from '../../core/runtime';
import { registerProtectedCleanup } from '../../core/protectedResources';
import { protectedImage, removePrepared } from '../../platform/images';
import { native } from '../../platform/native';
import { reportContent } from './reportContent';

const ink = rgb(0.09, 0.1, 0.13),
  purple = rgb(0.427, 0.157, 0.851),
  muted = rgb(0.4, 0.4, 0.45),
  soft = rgb(0.96, 0.95, 0.98),
  border = rgb(0.87, 0.85, 0.91);
const directory = () => new Directory(Paths.cache, 'ekspersiz-pdf');
const artifacts: string[] = [];
function clearPdfs() {
  artifacts.length = 0;
  try {
    const folder = directory();
    if (folder.exists) folder.delete();
  } catch {
    /* Next scope never receives an old path. */
  }
}
registerProtectedCleanup(clearPdfs);
clearPdfs();
export type PdfBlock =
  | {
      type: 'text';
      text: string;
      size?: number;
      bold?: boolean;
      muted?: boolean;
      box?: boolean;
    }
  | { type: 'grid'; rows: string[][] }
  | { type: 'image' };
const text = (value: unknown) => (value == null ? '—' : String(value));
export function recordSnapshot(record: DamageRecord) {
  if (record.status !== 'FINALIZED' || !record.snapshotJson)
    throw new Error(
      'PDF yalnızca kesinleştirilmiş tutanak için oluşturulabilir.',
    );
  let snapshot: unknown;
  try {
    snapshot = JSON.parse(record.snapshotJson);
  } catch {
    throw new Error('Kesinleştirilmiş tutanak verisi okunamadı.');
  }
  if (
    !isRecord(snapshot) ||
    !isRecord(snapshot.vehicle) ||
    !isRecord(snapshot.analysis)
  )
    throw new Error('Kesinleştirilmiş tutanak verisi geçersiz.');
  if (
    snapshot.analysis.inspectionId != null &&
    snapshot.analysis.inspectionId !== record.inspectionId
  )
    throw new Error('Tutanak ve inceleme kimlikleri eşleşmiyor.');
  return snapshot;
}
export const legalRecordDisclaimer =
  'Bu belge EksperSiz tarafından kullanıcı beyanı ve yapay zekâ destekli görüntü analizi kullanılarak oluşturulmuştur. Yetkili sigorta eksperi raporu, kolluk trafik kazası tespit tutanağı veya SBM Maddi Hasarlı Trafik Kazası Tespit Tutanağı yerine geçmez.';
export function reportBlocks(inspection: Inspection): PdfBlock[] {
  if (inspection.status !== 'COMPLETED' || !inspection.report)
    throw new Error('Tamamlanmış bir AI raporu gereklidir.');
  const content = reportContent(inspection),
    blocks: PdfBlock[] = [
      { type: 'text', text: 'Hasar Analiz Raporu', size: 22, bold: true },
      {
        type: 'text',
        text: `Rapor No: EXP-${inspection.id} • ${dateText(inspection.completedAt)}`,
        size: 9,
        muted: true,
      },
      { type: 'text', text: 'Araç Bilgileri', size: 12.5, bold: true },
      {
        type: 'grid',
        rows: [
          [
            'Plaka',
            inspection.vehiclePlate,
            'Araç',
            `${inspection.vehicleBrand} ${inspection.vehicleModel}`,
          ],
          [
            'Model Yılı',
            String(inspection.vehicleModelYear),
            'Kilometre',
            `${number(inspection.vehicleMileage)} km`,
          ],
        ],
      },
      { type: 'text', text: content.title, size: 16, bold: true },
    ];
  if (inspection.analysisMessage)
    blocks.push({ type: 'text', text: inspection.analysisMessage, box: true });
  if (inspection.additionalPhotoGuidance)
    blocks.push({
      type: 'text',
      text: inspection.additionalPhotoGuidance,
      box: true,
    });
  blocks.push({ type: 'image' });
  for (const finding of content.findings) {
    blocks.push(
      { type: 'text', text: finding.part, size: 12, bold: true },
      { type: 'text', text: finding.damageTypes.join(' • ') },
      {
        type: 'text',
        text: [...finding.observations, ...finding.repairs].join('\n'),
      },
    );
  }
  for (const narrative of content.narrative)
    blocks.push({ type: 'text', text: narrative });
  blocks.push(
    { type: 'text', text: content.priceTitle, size: 12.5, bold: true },
    { type: 'text', text: content.price, size: 18, bold: true },
  );
  for (const note of [
    inspection.report.priceInformation,
    inspection.report.priceSourceDescription,
    content.disclaimer,
  ])
    if (note) blocks.push({ type: 'text', text: note, box: true });
  return blocks;
}
export function recordBlocks(record: DamageRecord): PdfBlock[] {
  const snapshot = recordSnapshot(record),
    vehicle = snapshot.vehicle as Record<string, unknown>,
    analysis = snapshot.analysis as Record<string, unknown>,
    report = isRecord(snapshot.report) ? snapshot.report : null;
  const blocks: PdfBlock[] = [
    {
      type: 'text',
      text: 'Araç Hasar Durum ve Beyan Tutanağı',
      size: 22,
      bold: true,
    },
    {
      type: 'text',
      text: `Belge No: ${record.recordNumber} • Sürüm: ${record.documentVersion}`,
      size: 9,
      muted: true,
    },
    { type: 'text', text: 'Araç Bilgileri', size: 12.5, bold: true },
    {
      type: 'grid',
      rows: [
        [
          'Plaka',
          text(vehicle.plate),
          'Araç',
          `${text(vehicle.brand)} ${text(vehicle.model)}`,
        ],
        [
          'Model Yılı',
          text(vehicle.modelYear),
          'Kilometre',
          `${text(vehicle.mileage)} km`,
        ],
      ],
    },
    {
      type: 'text',
      text: 'Olay Bilgileri ve Kullanıcı Beyanı',
      size: 12.5,
      bold: true,
    },
    {
      type: 'grid',
      rows: [
        [
          'Olay Tarihi',
          dateText(text(snapshot.incidentDateTime)),
          'İl / İlçe',
          [snapshot.incidentCity, snapshot.incidentDistrict]
            .filter(Boolean)
            .join(' / '),
        ],
        [
          'Adres / Konum',
          text(snapshot.incidentAddress),
          'Beyan Sahibi',
          text(snapshot.declarantFullName),
        ],
      ],
    },
    { type: 'text', text: text(snapshot.incidentDescription), box: true },
    { type: 'text', text: 'İnceleme Fotoğrafı', size: 12.5, bold: true },
    { type: 'image' },
    { type: 'text', text: 'AI Teknik Değerlendirmesi', size: 12.5, bold: true },
    {
      type: 'grid',
      rows: [
        [
          'Hasar Seviyesi',
          label(text(analysis.damageSeverity)),
          'Güven Skoru',
          typeof analysis.confidenceScore === 'number'
            ? `%${Math.round(analysis.confidenceScore * 100)}`
            : '—',
        ],
        [
          'Analiz Tarihi',
          dateText(text(analysis.completedAt)),
          'İnceleme No',
          text(analysis.inspectionId),
        ],
      ],
    },
  ];
  if (analysis.analysisMessage)
    blocks.push({
      type: 'text',
      text: text(analysis.analysisMessage),
      box: true,
    });
  if (report) {
    blocks.push(
      { type: 'text', text: 'Detaylı AI Raporu', size: 12.5, bold: true },
      {
        type: 'text',
        text: [
          report.summary,
          report.damageDescription,
          report.repairRecommendation,
        ]
          .filter(Boolean)
          .join('\n\n'),
        box: true,
      },
    );
    if (Number(report.estimatedMaximumPrice) > 0)
      blocks.push({
        type: 'text',
        text: `${analysis.schemaVersion === 'hitl-v1' || (Array.isArray(analysis.repairRecommendations) && analysis.repairRecommendations.length > 0 && analysis.repairRecommendations.every((item) => isRecord(item) && item.recommendedAction === 'PROFESSIONAL_INSPECTION')) ? 'Tahmini fiziksel inceleme aralığı' : 'Tahmini onarım aralığı'}: ${text(report.estimatedMinimumPrice)} – ${text(report.estimatedMaximumPrice)} ${text(report.currency)}`,
        box: true,
      });
  }
  blocks.push(
    { type: 'text', text: 'Belge Doğrulama Bilgisi', size: 12.5, bold: true },
    {
      type: 'text',
      text: `Kesinleştirme: ${dateText(record.finalizedAt)}\nSHA-256: ${record.contentHash ?? '—'}`,
      size: 8,
      box: true,
    },
    { type: 'text', text: legalRecordDisclaimer, size: 9, box: true },
  );
  return blocks;
}
/** A4 with the original embedded Roboto fonts. All untrusted values are plain text. */
export async function buildPdf(
  blocks: PdfBlock[],
  assets: {
    regular: Uint8Array;
    bold: Uint8Array;
    logo: Uint8Array;
    photo: Uint8Array;
  },
  finalized = false,
) {
  const document = await PDFDocument.create();
  document.registerFontkit(fontkit);
  document.setTitle(
    finalized
      ? 'EksperSiz Araç Hasar Durum ve Beyan Tutanağı'
      : 'EksperSiz Hasar Analiz Raporu',
  );
  document.setCreator('EksperSiz');
  const regular = await document.embedFont(assets.regular, { subset: true }),
    bold = await document.embedFont(assets.bold, { subset: true }),
    fallback = await document.embedFont(StandardFonts.Helvetica);
  const logo = await document.embedPng(assets.logo),
    photo =
      assets.photo[0] === 0x89
        ? await document.embedPng(assets.photo)
        : await document.embedJpg(assets.photo);
  const width = 595.28,
    height = 841.89,
    margin = 32,
    contentWidth = width - margin * 2,
    bottom = 52;
  let page: PDFPage = document.addPage([width, height]),
    y = height - 86;
  const next = () => {
    page = document.addPage([width, height]);
    y = height - 86;
  };
  const ensure = (amount: number) => {
    if (y - amount < bottom) next();
  };
  const wrap = (
    value: string,
    font: PDFFont,
    size: number,
    maxWidth: number,
  ) => {
    const lines: string[] = [];
    for (const paragraph of value.replace(/\r/g, '').split('\n')) {
      let line = '';
      for (const word of paragraph.split(/\s+/)) {
        const candidate = line ? `${line} ${word}` : word;
        if (font.widthOfTextAtSize(candidate, size) <= maxWidth) {
          line = candidate;
          continue;
        }
        if (line) lines.push(line);
        line = '';
        for (const character of Array.from(word)) {
          if (
            line &&
            font.widthOfTextAtSize(line + character, size) > maxWidth
          ) {
            lines.push(line);
            line = '';
          }
          line += character;
        }
      }
      lines.push(line);
    }
    return lines;
  };
  for (const block of blocks) {
    // Keep section headings with at least the first content line on the next page.
    if (block.type === 'text' && block.bold) ensure(72);
    if (block.type === 'image') {
      ensure(246);
      const factor = Math.min(contentWidth / photo.width, 230 / photo.height);
      page.drawRectangle({
        x: margin,
        y: y - 234,
        width: contentWidth,
        height: 234,
        borderColor: border,
        borderWidth: 0.7,
      });
      page.drawImage(photo, {
        x: margin + (contentWidth - photo.width * factor) / 2,
        y: y - 232 + (230 - photo.height * factor) / 2,
        width: photo.width * factor,
        height: photo.height * factor,
      });
      y -= 250;
      continue;
    }
    if (block.type === 'grid') {
      for (const row of block.rows) {
        const column = contentWidth / 4,
          lines = row.map((value, index) =>
            wrap(value, index % 2 === 0 ? bold : regular, 8.7, column - 16),
          ),
          rowHeight = Math.max(...lines.map((line) => line.length)) * 11 + 16;
        ensure(rowHeight + 8);
        for (let index = 0; index < 4; index++) {
          page.drawRectangle({
            x: margin + column * index,
            y: y - rowHeight,
            width: column,
            height: rowHeight,
            color: index % 2 === 0 ? soft : rgb(1, 1, 1),
            borderColor: border,
            borderWidth: 0.7,
          });
          lines[index]?.forEach((line, lineIndex) =>
            page.drawText(line, {
              x: margin + column * index + 8,
              y: y - 15 - lineIndex * 11,
              size: 8.7,
              font: index % 2 === 0 ? bold : regular,
              color: ink,
            }),
          );
        }
        y -= rowHeight;
      }
      y -= 14;
      continue;
    }
    const size = block.size ?? 9,
      lineHeight = size * 1.45,
      font = block.bold ? bold : regular,
      inset = block.box ? 11 : 0,
      lines = wrap(block.text, font, size, contentWidth - inset * 2);
    if (block.bold) ensure(Math.min(lines.length * lineHeight + 30, 180));
    for (const line of lines) {
      ensure(lineHeight + inset);
      if (block.box)
        page.drawRectangle({
          x: margin,
          y: y - lineHeight - 3,
          width: contentWidth,
          height: lineHeight + 5,
          color: soft,
        });
      page.drawText(line, {
        x: margin + inset,
        y: y - size,
        size,
        font,
        color: block.muted ? muted : ink,
      });
      y -= lineHeight;
    }
    y -= block.bold ? 9 : 13;
  }
  const pages = document.getPages();
  pages.forEach((current, index) => {
    current.drawRectangle({
      x: margin,
      y: height - 70,
      width: 38,
      height: 38,
      color: purple,
    });
    current.drawImage(logo, {
      x: margin + 4,
      y: height - 66,
      width: 30,
      height: 30,
    });
    current.drawText('EksperSiz', {
      x: margin + 47,
      y: height - 56,
      size: 18,
      font: bold,
      color: ink,
    });
    current.drawText(
      finalized ? 'KESİNLEŞTİRİLMİŞ TUTANAK' : 'AI HASAR RAPORU',
      {
        x: width - margin - 165,
        y: height - 52,
        size: 8,
        font: bold,
        color: purple,
      },
    );
    current.drawText(
      'EksperSiz • Kullanıcı beyanı + AI görünür hasar analizi',
      { x: margin, y: 29, size: 7.5, font: regular, color: muted },
    );
    current.drawText(`${index + 1} / ${pages.length}`, {
      x: width - margin - 32,
      y: 29,
      size: 7.5,
      font: fallback,
      color: muted,
    });
  });
  return document.save();
}
async function assetBytes(module: number) {
  const asset = Asset.fromModule(module);
  await asset.downloadAsync();
  if (!asset.localUri) throw new Error('PDF varlıkları yüklenemedi.');
  return new File(asset.localUri).bytes();
}
export async function sharePdf(inspection: Inspection, record?: DamageRecord) {
  const generation = session.getSnapshot().generation;
  if (record) {
    const snapshot = recordSnapshot(record);
    const snapshotAnalysis = snapshot.analysis as Record<string, unknown>;
    if (
      snapshotAnalysis.imagePath &&
      snapshotAnalysis.imagePath !== inspection.imagePath
    )
      throw new Error(
        'Kesinleştirilmiş tutanağın fotoğrafı değişmiş. Belge paylaşılamıyor.',
      );
    if (record.contentHash) {
      const hash = await Crypto.digestStringAsync(
        Crypto.CryptoDigestAlgorithm.SHA256,
        record.snapshotJson!,
      );
      if (hash.toLowerCase() !== record.contentHash.toLowerCase())
        throw new Error('Tutanak içeriği doğrulanamadı. Belge paylaşılamıyor.');
    }
  }
  session.check(generation);
  if (!(await Sharing.isAvailableAsync()))
    throw new Error('Bu cihazda dosya paylaşımı kullanılamıyor.');
  const blocks = record ? recordBlocks(record) : reportBlocks(inspection),
    image = await protectedImage(inspection.id);
  session.check(generation);
  const prepared = await native().prepareImage(image);
  let photo: Uint8Array;
  try {
    photo = await new File(prepared.uri).bytes();
  } finally {
    removePrepared(prepared.uri);
  }
  const [regular, bold, logo] = await Promise.all([
    assetBytes(require('../../../assets/fonts/Roboto-Regular.ttf')),
    assetBytes(require('../../../assets/fonts/Roboto-Bold.ttf')),
    assetBytes(require('../../../assets/images/ekspersiz_logo.png')),
  ]);
  session.check(generation);
  const bytes = await buildPdf(
    blocks,
    { regular, bold, logo, photo },
    !!record,
  );
  session.check(generation);
  const folder = directory();
  folder.create({ idempotent: true, intermediates: true });
  const identifier = (record?.recordNumber ?? String(inspection.id)).replace(
    /[^0-9A-Za-z-]/g,
    '',
  );
  const file = new File(
    folder,
    `EksperSiz_${record ? 'Tutanak' : 'Rapor'}_${identifier}.pdf`,
  );
  file.write(bytes);
  session.check(generation);
  artifacts.push(file.uri);
  while (artifacts.length > 3) {
    const old = artifacts.shift();
    if (old && old !== file.uri) {
      const previous = new File(old);
      if (previous.exists) previous.delete();
    }
  }
  await Sharing.shareAsync(file.uri, {
    mimeType: 'application/pdf',
    UTI: 'com.adobe.pdf',
    dialogTitle: record
      ? 'Araç Hasar Durum ve Beyan Tutanağı'
      : 'Hasar Analiz Raporu',
  });
}
