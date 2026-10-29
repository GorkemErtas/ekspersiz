import { inspectionLabels } from './inspectionLabels';
export const labels: Record<string, string> = {
  FREE: 'Ücretsiz',
  PLUS: 'Plus',
  PRO: 'Pro',
  BUSINESS: 'Business',
  PERSONAL: 'Kişisel',
  OWNER: 'Şirket sahibi',
  MEMBER: 'Şirket üyesi',
  ACTIVE: 'Aktif',
  EXPIRED: 'Süresi doldu',
  NONE: 'Yok',
  UNKNOWN: 'Belirsiz',
  GOOD: 'İyi durumda',
  UPCOMING: 'Yaklaşıyor',
  OVERDUE: 'Gecikti',
  COMPLETED: 'Tamamlandı',
  PENDING: 'Bekliyor',
  PROCESSING: 'İşleniyor',
  FAILED: 'Başarısız',
  CANCELLED: 'İptal edildi',
  DRAFT: 'Taslak',
  FINALIZED: 'Kesinleştirildi',
  ENGINE_OIL: 'Motor yağı',
  OIL_FILTER: 'Yağ filtresi',
  AIR_FILTER: 'Hava filtresi',
  CABIN_FILTER: 'Polen filtresi',
  BRAKE_PADS: 'Fren balataları',
  BRAKE_FLUID: 'Fren hidroliği',
  BATTERY: 'Akü',
  TIRES: 'Lastikler',
  TIMING_SYSTEM: 'Triger sistemi',
  TRANSMISSION: 'Şanzıman',
  PERIODIC_MAINTENANCE: 'Periyodik bakım',
  VEHICLE_INSPECTION: 'Araç muayenesi',
  TRAFFIC_INSURANCE: 'Trafik sigortası',
  COMPREHENSIVE_INSURANCE: 'Kasko',
  TIRE_CHECK: 'Lastik kontrolü',
  CUSTOM: 'Diğer',
  MINOR: 'Hafif',
  MODERATE: 'Orta',
  SEVERE: 'Ağır',
  NO_DAMAGE: 'Hasar yok',
  SCRATCH: 'Çizik',
  DENT: 'Göçük',
  CRACK: 'Çatlak',
  BROKEN_GLASS: 'Cam kırığı',
  PAINT_DAMAGE: 'Boya hasarı',
  FRONT: 'Ön',
  REAR: 'Arka',
  FRONT_BUMPER: 'Ön tampon',
  REAR_BUMPER: 'Arka tampon',
  HOOD: 'Kaput',
  TRUNK: 'Bagaj',
  DOOR: 'Kapı',
  FENDER: 'Çamurluk',
  WINDSHIELD: 'Ön cam',
  ROOF: 'Tavan',
  PROFESSIONAL_INSPECTION: 'Profesyonel inceleme',
  NO_ACTION: 'İşlem gerekmiyor',
  REPAIR: 'Onarım',
  REPLACE: 'Değişim',
  UNDETERMINED: 'Belirlenemedi',
  ANALYSIS: 'Analiz',
  ASSISTANT: 'Asistan',
  VEHICLE_SLOT: 'Araç kapasitesi',
  NEEDS_MORE_PHOTOS: 'Ek fotoğraf gerekli',
  INCONCLUSIVE: 'Kesin sonuca ulaşılamadı',
};
export const label = (value: string | null | undefined) =>
  value
    ? (inspectionLabels[value] ?? labels[value] ?? value.replaceAll('_', ' '))
    : '—';
export const number = (value: number) =>
  new Intl.NumberFormat('tr-TR').format(value);
export const money = (value: number, currency = 'TRY') =>
  new Intl.NumberFormat('tr-TR', { style: 'currency', currency }).format(value);
export const dateText = (value?: string | null) =>
  value && !Number.isNaN(new Date(value).getTime())
    ? new Intl.DateTimeFormat('tr-TR').format(new Date(value))
    : 'Seçilmedi';
export const isoDate = (value: Date) =>
  `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;
