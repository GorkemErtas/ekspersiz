import type { Maintenance, Reminder } from '../../core/models';
export const maintenanceTypes = [
  'ENGINE_OIL',
  'OIL_FILTER',
  'AIR_FILTER',
  'CABIN_FILTER',
  'BRAKE_PADS',
  'BRAKE_FLUID',
  'BATTERY',
  'TIRES',
  'TIMING_SYSTEM',
  'TRANSMISSION',
  'PERIODIC_MAINTENANCE',
  'CUSTOM',
];
export const reminderTypes = [
  'PERIODIC_MAINTENANCE',
  'VEHICLE_INSPECTION',
  'TRAFFIC_INSURANCE',
  'COMPREHENSIVE_INSURANCE',
  'TIRE_CHECK',
  'CUSTOM',
];
export function trackingPayload(
  kind: 'maintenance' | 'reminders',
  values: Record<string, string>,
  first: boolean,
  manual: boolean,
  original?: Maintenance | Reminder,
) {
  const numeric = (key: string, max = 2_000_000, min = 0) => {
    const text = values[key] ?? '';
    if (!text.trim()) return undefined;
    const number = Number(text.replace(',', '.'));
    if (
      !Number.isFinite(number) ||
      number < min ||
      number > max ||
      (key !== 'cost' && !Number.isInteger(number))
    )
      throw new Error('Kilometre, tutar veya aralık geçersiz.');
    return number;
  };
  const body: Record<string, unknown> = {};
  const type = values.type!;
  if (kind === 'maintenance') {
    if (!values.date || values.mileage === '')
      throw new Error('Bakım tarihi ve kilometre girin.');
    Object.assign(body, {
      maintenanceType: type,
      maintenanceDate: values.date,
      mileage: numeric('mileage'),
      cost: numeric('cost', Number.MAX_SAFE_INTEGER),
      note: values.note?.trim() || undefined,
      intervalMonths: numeric('intervalMonths', 600, 1),
      intervalMileage: numeric('intervalMileage', 2_000_000, 1),
    });
    const previous = original as Maintenance | undefined;
    if (
      !body.intervalMonths &&
      !body.intervalMileage &&
      !previous?.intervalMonths &&
      !previous?.intervalMileage
    )
      Object.assign(body, {
        nextRecommendedDate: previous?.nextRecommendedDate ?? undefined,
        nextRecommendedMileage: previous?.nextRecommendedMileage ?? undefined,
      });
  } else {
    Object.assign(body, {
      reminderType: type,
      title: values.title?.trim() || undefined,
      note: values.note?.trim() || undefined,
    });
    if (type === 'CUSTOM' && !body.title) throw new Error('Başlık girin.');
    if (type === 'VEHICLE_INSPECTION') {
      if (!values.sourceDate)
        throw new Error('Son araç muayene tarihini girin.');
      Object.assign(body, {
        sourceDate: values.sourceDate,
        firstInspection: first,
      });
    } else if (type === 'PERIODIC_MAINTENANCE' && !manual) {
      const months = numeric('intervalMonths', 600, 1),
        mileage = numeric('intervalMileage', 2_000_000, 1);
      if (!months && !mileage)
        throw new Error('Ay veya kilometre bakım aralığı girin.');
      if (months && !values.sourceDate)
        throw new Error('Son bakım tarihini girin.');
      Object.assign(body, {
        sourceDate: values.sourceDate || undefined,
        sourceMileage: numeric('sourceMileage'),
        intervalMonths: months,
        intervalMileage: mileage,
      });
    } else {
      Object.assign(body, {
        dueDate: values.dueDate || undefined,
        ...(['CUSTOM', 'TIRE_CHECK', 'PERIODIC_MAINTENANCE'].includes(type)
          ? { dueMileage: numeric('dueMileage') }
          : {}),
      });
      if (!body.dueDate && body.dueMileage == null)
        throw new Error('Tarih veya kilometre hedefi girin.');
    }
  }
  return Object.fromEntries(
    Object.entries(body).filter(([, value]) => value !== undefined),
  );
}
