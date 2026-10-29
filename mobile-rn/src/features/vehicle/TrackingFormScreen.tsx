import { useState } from 'react';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { vehicles } from '../../core/services';
import { positiveId, type Maintenance, type Reminder } from '../../core/models';
import { invalidate, useResource } from '../../core/queries';
import { isoDate } from '../../core/labels';
import { AppText, Button, Card, Field, Gap } from '../../design/components';
import {
  DateField,
  Heading,
  Page,
  Select,
  StateView,
  Toggle,
} from '../../design/layout';
import { useAction } from '../auth/useAction';

import { maintenanceTypes, reminderTypes, trackingPayload } from './tracking';
export default function TrackingFormScreen() {
  const params = useLocalSearchParams<{
    vehicle: string;
    kind: string;
    edit?: string;
  }>();
  const id = positiveId(params.vehicle),
    edit = params.edit ? positiveId(params.edit) : undefined,
    kind = params.kind === 'maintenance' ? 'maintenance' : 'reminders';
  const vehicle = useResource(`vehicles/${id}`, (s) => vehicles.get(id, s));
  const records = useResource<(Maintenance | Reminder)[]>(
    `vehicles/${id}/${kind}`,
    (s) =>
      kind === 'maintenance'
        ? vehicles.maintenance(id, s)
        : vehicles.reminders(id, s),
  );
  const original = records.data?.find((item) => item.id === edit);
  return (
    <Page
      title={
        kind === 'maintenance'
          ? edit
            ? 'Bakımı Düzenle'
            : 'Bakım Ekle'
          : edit
            ? 'Hatırlatmayı Düzenle'
            : 'Hatırlatma Ekle'
      }
    >
      {!vehicle.data || (edit && !records.data) ? (
        <StateView
          loading={vehicle.isPending || records.isPending}
          error={vehicle.error ?? records.error}
          retry={() => void invalidate(`vehicles/${id}`)}
        />
      ) : edit && !original ? (
        <StateView error={new Error('Kayıt bulunamadı.')} />
      ) : (
        <TrackingForm
          vehicleId={id}
          mileage={vehicle.data.mileage}
          kind={kind}
          original={original}
        />
      )}
    </Page>
  );
}
function TrackingForm({
  vehicleId,
  mileage,
  kind,
  original,
}: {
  vehicleId: number;
  mileage: number;
  kind: 'maintenance' | 'reminders';
  original?: Maintenance | Reminder;
}) {
  const router = useRouter();
  const action = useAction();
  const reminder = original as Reminder | undefined,
    maintenance = original as Maintenance | undefined;
  const [first, setFirst] = useState(reminder?.firstInspection ?? false);
  const [manual, setManual] = useState(
    !!original &&
      !reminder?.sourceDate &&
      reminder?.sourceMileage == null &&
      !reminder?.intervalMonths &&
      !reminder?.intervalMileage,
  );
  const [values, setValues] = useState<Record<string, string>>({
    type:
      kind === 'maintenance'
        ? (maintenance?.maintenanceType ?? 'PERIODIC_MAINTENANCE')
        : (reminder?.reminderType ?? 'VEHICLE_INSPECTION'),
    date: maintenance?.maintenanceDate ?? isoDate(new Date()),
    mileage: String(maintenance?.mileage ?? mileage),
    cost: maintenance?.cost?.toString() ?? '',
    note: original?.note ?? '',
    title: reminder?.title ?? '',
    sourceDate: reminder?.sourceDate ?? '',
    sourceMileage: String(reminder?.sourceMileage ?? mileage),
    intervalMonths: original?.intervalMonths?.toString() ?? '',
    intervalMileage: original?.intervalMileage?.toString() ?? '',
    dueDate: reminder?.dueDate ?? '',
    dueMileage: reminder?.dueMileage?.toString() ?? '',
  });
  const change = (key: string, value: string) =>
    setValues((v) => ({ ...v, [key]: value }));
  const input = (key: string, title: string, numeric = true) => (
    <>
      <Field
        label={title}
        icon={numeric ? 'car' : 'edit'}
        value={values[key] ?? ''}
        onChangeText={(v) => change(key, v)}
        keyboardType={numeric ? 'decimal-pad' : 'default'}
        multiline={!numeric && key === 'note'}
        maxLength={numeric ? 16 : key === 'title' ? 120 : 1000}
      />
      <Gap />
    </>
  );
  const date = (key: string, title: string) => (
    <DateField
      title={title}
      value={values[key] ?? ''}
      onChange={(v) => change(key, v)}
    />
  );
  return (
    <>
      <Heading
        title={
          kind === 'maintenance'
            ? 'Bakım bilgileri'
            : 'Bir sonraki işlemi planlayın'
        }
        description={
          kind === 'maintenance'
            ? 'Bakım tarihini, kilometreyi ve yapılan işlemi kaydedin.'
            : 'Bakım, muayene ve sigorta tarihlerini tek yerden takip edin.'
        }
        icon={kind === 'maintenance' ? 'tools' : 'calendar'}
      />
      <Card>
        <Select
          title={kind === 'maintenance' ? 'Bakım Türü' : 'Hatırlatma türü'}
          value={values.type!}
          items={kind === 'maintenance' ? maintenanceTypes : reminderTypes}
          onChange={(v) => change('type', v)}
        />
        <Gap />
        {kind === 'maintenance' ? (
          <>
            {date('date', 'Bakım Tarihi')}
            {input('mileage', 'Kilometre')}
            {input('cost', 'Maliyet (TL)')}
            {input('intervalMonths', 'Bakım aralığı (ay)')}
            {input('intervalMileage', 'Bakım aralığı (km)')}
          </>
        ) : (
          <>
            {values.type === 'VEHICLE_INSPECTION' ? (
              <>
                {date('sourceDate', 'Son araç muayene tarihi')}
                <Toggle
                  title="İlk muayene (3 yıl)"
                  value={first}
                  onChange={setFirst}
                />
                <AppText>
                  Sonraki muayene tarihi sunucu tarafından hesaplanır.
                </AppText>
              </>
            ) : values.type === 'PERIODIC_MAINTENANCE' ? (
              <>
                <Toggle
                  title="Tarihi / kilometreyi kendim belirleyeceğim"
                  value={manual}
                  onChange={setManual}
                />
                {manual ? (
                  <>
                    {date('dueDate', 'Sonraki bakım tarihi')}
                    {input('dueMileage', 'Hedef kilometre')}
                  </>
                ) : (
                  <>
                    {date('sourceDate', 'Son bakım tarihi')}
                    {input('sourceMileage', 'Son bakım kilometresi')}
                    {input('intervalMonths', 'Bakım aralığı (ay)')}
                    {input('intervalMileage', 'Bakım aralığı (km)')}
                  </>
                )}
              </>
            ) : (
              <>
                {date('dueDate', 'Poliçede yazan bitiş / hedef tarihi')}
                {['CUSTOM', 'TIRE_CHECK'].includes(values.type!) &&
                  input('dueMileage', 'Hedef kilometre')}
              </>
            )}
            {values.type === 'CUSTOM' && input('title', 'Başlık', false)}
          </>
        )}
        {input('note', 'Not (isteğe bağlı)', false)}
        <Button
          label="Kaydet"
          icon="verified"
          loading={action.busy}
          onPress={() =>
            void action.run(
              async () => {
                const body = trackingPayload(
                  kind,
                  values,
                  first,
                  manual,
                  original,
                );
                return vehicles.saveTracking(
                  vehicleId,
                  kind,
                  body,
                  original?.id,
                );
              },
              () => {
                void invalidate(`vehicles/${vehicleId}`, 'notifications');
                router.back();
              },
            )
          }
        />
      </Card>
    </>
  );
}
