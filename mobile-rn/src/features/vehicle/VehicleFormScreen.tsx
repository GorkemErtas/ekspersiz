import { useState } from 'react';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { vehicles } from '../../core/services';
import { positiveId } from '../../core/models';
import { invalidate, useResource } from '../../core/queries';
import { AppText, Button, Card, Field, Gap } from '../../design/components';
import {
  DateField,
  Heading,
  Page,
  Select,
  StateView,
  Toggle,
} from '../../design/layout';
import { vehicleCatalog } from './catalog';
import { useAction } from '../auth/useAction';

const trackingDates = {
  lastMaintenanceDate: 'Son bakım tarihi',
  nextMaintenanceDate: 'Sonraki bakım tarihi',
  vehicleInspectionDate: 'Son araç muayene tarihi',
  trafficInsuranceExpiryDate: 'Trafik sigortası bitişi',
  comprehensiveInsuranceExpiryDate: 'Kasko bitişi',
  tireCheckDate: 'Lastik kontrol tarihi',
};
export default function VehicleFormScreen() {
  const { edit } = useLocalSearchParams<{ edit?: string }>();
  const id = edit ? positiveId(edit) : undefined;
  const data = useResource(
    `vehicles/${id}`,
    (signal) => vehicles.get(id!, signal),
    !!id,
  );
  return (
    <Page title={id ? 'Aracı Düzenle' : 'Araç Ekle'}>
      {id && !data.data ? (
        <StateView
          loading={data.isPending}
          error={data.error}
          retry={() => void data.refetch()}
        />
      ) : (
        <VehicleForm key={id ?? 'new'} initial={data.data} />
      )}
    </Page>
  );
}
function VehicleForm({
  initial,
}: {
  initial?: import('../../core/models').Vehicle;
}) {
  const router = useRouter();
  const action = useAction();
  const [form, setForm] = useState({
    plate: initial?.plate ?? '',
    brand: initial?.brand ?? '',
    model: initial?.model ?? '',
    modelYear: String(initial?.modelYear ?? new Date().getFullYear()),
    mileage: String(initial?.mileage ?? 0),
    notes: initial?.notes ?? '',
  });
  const [tracking, setTracking] = useState<Record<string, string>>({});
  const [first, setFirst] = useState(false);
  const change = (key: keyof typeof form, value: string) =>
    setForm((current) => ({ ...current, [key]: value }));
  const save = () => {
    if (
      !form.plate.trim() ||
      !form.brand.trim() ||
      !form.model.trim() ||
      !/^\d{4}$/.test(form.modelYear) ||
      Number(form.modelYear) < 1950 ||
      Number(form.modelYear) > new Date().getFullYear() + 1 ||
      !/^\d+$/.test(form.mileage) ||
      Number(form.mileage) > 2_000_000
    ) {
      action.show(
        'Plaka, marka, model, model yılı ve geçerli kilometre girin.',
      );
      return;
    }
    const trackingBody: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(tracking))
      if (value.trim()) {
        if (key.endsWith('Mileage') || key === 'maintenanceIntervalMonths') {
          const n = Number(value);
          if (
            !Number.isInteger(n) ||
            n < 0 ||
            n > 2_000_000 ||
            (key === 'maintenanceIntervalMonths' && (n < 1 || n > 600))
          ) {
            action.show('Bakım aralıklarını kontrol edin.');
            return;
          }
          trackingBody[key] = n;
        } else trackingBody[key] = value;
      }
    if (trackingBody.vehicleInspectionDate)
      trackingBody.firstInspection = first;
    void action.run(
      () =>
        vehicles.save(
          {
            ...form,
            modelYear: Number(form.modelYear),
            mileage: Number(form.mileage),
            ...(!initial ? { tracking: trackingBody } : {}),
          },
          initial?.id,
        ),
      () => {
        void invalidate('vehicles', 'credits', 'inspections');
        router.back();
      },
    );
  };
  return (
    <>
      <Heading
        title="Araç bilgileri"
        description="Aracınızı kaydedin, bakım ve analiz geçmişini takip edin."
      />
      <Card>
        <Field
          label="Plaka"
          icon="car"
          value={form.plate}
          onChangeText={(v) => change('plate', v)}
          autoCapitalize="characters"
          maxLength={20}
        />
        <Gap />
        <Select
          title="Marka"
          value={form.brand}
          items={[
            { value: '', title: 'Marka seçin' },
            ...Object.keys(vehicleCatalog).map((value) => ({
              value,
              title: value,
            })),
          ]}
          onChange={(v) => {
            change('brand', v);
            change('model', '');
          }}
        />
        <Gap />
        <Select
          title="Model"
          value={form.model}
          items={[
            { value: '', title: 'Model seçin' },
            ...(vehicleCatalog[form.brand] ?? []).map((value) => ({
              value,
              title: value,
            })),
          ]}
          onChange={(v) => change('model', v)}
        />
        <Gap />
        <Field
          label="Model yılı"
          icon="calendar"
          value={form.modelYear}
          onChangeText={(v) => change('modelYear', v)}
          keyboardType="number-pad"
        />
        <Gap />
        <Field
          label="Kilometre"
          icon="car"
          value={form.mileage}
          onChangeText={(v) => change('mileage', v)}
          keyboardType="number-pad"
        />
        <Gap />
        <Field
          label="Notlar"
          icon="edit"
          value={form.notes}
          onChangeText={(v) => change('notes', v)}
          multiline
          maxLength={1000}
        />
      </Card>
      {!initial && (
        <Card>
          <AppText variant="titleLarge">Bakım ve hatırlatma başlangıcı</AppText>
          <Gap />
          {Object.entries(trackingDates).map(([key, title]) => (
            <DateField
              key={key}
              title={title}
              value={tracking[key] ?? ''}
              onChange={(v) =>
                setTracking((current) => ({ ...current, [key]: v }))
              }
            />
          ))}
          <Toggle
            title="İlk araç muayenesi"
            value={first}
            onChange={setFirst}
          />
          {Object.entries({
            lastMaintenanceMileage: 'Son bakım kilometresi',
            nextMaintenanceMileage: 'Sonraki bakım kilometresi',
            maintenanceIntervalMonths: 'Bakım aralığı (ay)',
            maintenanceIntervalMileage: 'Bakım aralığı (km)',
          }).map(([key, title]) => (
            <Field
              key={key}
              label={title}
              icon="tools"
              value={tracking[key] ?? ''}
              onChangeText={(v) =>
                setTracking((current) => ({ ...current, [key]: v }))
              }
              keyboardType="number-pad"
            />
          ))}
        </Card>
      )}
      <Button
        label="Kaydet"
        icon="verified"
        loading={action.busy}
        onPress={save}
      />
    </>
  );
}
