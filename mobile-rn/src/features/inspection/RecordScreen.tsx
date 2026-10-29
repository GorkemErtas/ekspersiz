import { useState } from 'react';
import { View } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { useSession } from '../../core/runtime';
import { inspections } from '../../core/services';
import { useResource, invalidate } from '../../core/queries';
import {
  positiveId,
  type DamageRecord,
  type Inspection,
  type RecordInput,
} from '../../core/models';
import { dateText, isoDate } from '../../core/labels';
import { AppText, Button, Card, Field, Gap } from '../../design/components';
import {
  Badge,
  DateField,
  Heading,
  Page,
  StateView,
  confirm,
} from '../../design/layout';
import { useAction } from '../auth/useAction';
import { legalRecordDisclaimer, sharePdf } from './pdf';
export function recordPayload(input: RecordInput) {
  if (
    !input.incidentCity.trim() ||
    !input.declarantFullName.trim() ||
    !input.incidentDescription.trim()
  )
    throw new Error('Şehir, olay açıklaması ve beyan sahibini girin.');
  const date = new Date(input.incidentDateTime);
  if (
    Number.isNaN(date.getTime()) ||
    date.getTime() > Date.now() + 60_000 ||
    date.getFullYear() < 2000
  )
    throw new Error('Geçerli bir geçmiş olay tarihi ve saati seçin.');
  return {
    ...input,
    incidentCity: input.incidentCity.trim(),
    incidentDistrict: input.incidentDistrict?.trim() || null,
    incidentAddress: input.incidentAddress?.trim() || null,
    incidentDescription: input.incidentDescription.trim(),
    declarantFullName: input.declarantFullName.trim(),
  };
}
export default function RecordScreen() {
  const { id: raw } = useLocalSearchParams<{ id: string }>(),
    id = positiveId(raw),
    data = useResource(`inspection/${id}`, (signal) =>
      inspections.get(id, signal),
    ),
    record = useResource(`inspection/${id}/record`, (signal) =>
      inspections.record(id, signal),
    );
  return (
    <Page title="Hasar Durum ve Beyan Tutanağı">
      {data.isPending || record.isPending || data.error || record.error ? (
        <StateView
          loading={data.isPending || record.isPending}
          error={data.error ?? record.error}
          retry={() => {
            void data.refetch();
            void record.refetch();
          }}
        />
      ) : data.data?.status !== 'COMPLETED' ? (
        <StateView empty="Tutanak için tamamlanmış analiz gereklidir." />
      ) : (
        <RecordForm
          key={record.data?.updatedAt ?? 'new'}
          inspection={data.data}
          initial={record.data ?? null}
        />
      )}
    </Page>
  );
}
function RecordForm({
  inspection,
  initial,
}: {
  inspection: Inspection;
  initial: DamageRecord | null;
}) {
  const { profile } = useSession(),
    action = useAction(),
    [record, setRecord] = useState(initial),
    [form, setForm] = useState<RecordInput>({
      incidentDateTime:
        initial?.incidentDateTime ??
        `${isoDate(new Date())}T${new Date().toTimeString().slice(0, 8)}`,
      incidentCity: initial?.incidentCity ?? inspection.locationCity,
      incidentDistrict: initial?.incidentDistrict ?? null,
      incidentAddress: initial?.incidentAddress ?? null,
      incidentDescription: initial?.incidentDescription ?? '',
      declarantFullName: initial?.declarantFullName ?? profile?.fullName ?? '',
    });
  const readOnly = record?.status === 'FINALIZED',
    change = (key: keyof RecordInput, value: string) =>
      setForm((current) => ({ ...current, [key]: value }));
  const save = async () => {
    const saved = await inspections.saveRecord(
      inspection.id,
      recordPayload(form),
      !!record,
    );
    setRecord(saved);
    return saved;
  };
  return (
    <>
      <Heading
        title="Kullanıcı Beyanı ve AI Ön Değerlendirmesi"
        description="Olay bilgilerini kontrol edin. Kesinleştirilen tutanak düzenlenemez."
        icon="report"
      />
      {record && (
        <Badge
          text={`${record.recordNumber} • ${readOnly ? 'Kesinleştirildi' : 'Taslak'}`}
        />
      )}
      <Card>
        {readOnly ? (
          <AppText>
            Olay tarihi: {dateText(form.incidentDateTime)}{' '}
            {new Date(form.incidentDateTime).toLocaleTimeString('tr-TR')}
          </AppText>
        ) : (
          <DateField
            title="Olay Tarihi ve Saati"
            value={form.incidentDateTime}
            onChange={(value) => change('incidentDateTime', value)}
            optional={false}
            time
          />
        )}
        <Gap />
        {(
          [
            { key: 'incidentCity', title: 'Şehir', max: 100 },
            { key: 'incidentDistrict', title: 'İlçe', max: 100 },
            { key: 'incidentAddress', title: 'Adres / Konum', max: 500 },
            { key: 'incidentDescription', title: 'Olay Açıklaması', max: 3000 },
            {
              key: 'declarantFullName',
              title: 'Beyan Sahibi Ad Soyad',
              max: 150,
            },
          ] as const
        ).map((field) => (
          <View key={field.key} style={{ paddingBottom: 16 }}>
            {readOnly ? (
              <>
                <AppText variant="bodySmall">{field.title}</AppText>
                <AppText>{form[field.key] || '—'}</AppText>
              </>
            ) : (
              <Field
                label={field.title}
                icon={field.key === 'declarantFullName' ? 'person' : 'edit'}
                value={form[field.key] ?? ''}
                onChangeText={(value) => change(field.key, value)}
                maxLength={field.max}
                multiline={
                  field.key === 'incidentDescription' ||
                  field.key === 'incidentAddress'
                }
              />
            )}
          </View>
        ))}
      </Card>
      <Card>
        <AppText>{legalRecordDisclaimer}</AppText>
      </Card>
      {readOnly && record ? (
        <>
          <Card>
            <AppText>Kesinleştirme: {dateText(record.finalizedAt)}</AppText>
            <AppText selectable variant="bodySmall">
              SHA-256: {record.contentHash}
            </AppText>
          </Card>
          <Button
            label="Tutanak PDF’ini Paylaş"
            icon="share"
            loading={action.busy}
            onPress={() => void action.run(() => sharePdf(inspection, record))}
          />
        </>
      ) : (
        <>
          <Button
            label="Taslağı Kaydet"
            icon="verified"
            variant="outlined"
            loading={action.busy}
            onPress={() =>
              void action.run(save, () =>
                action.show('Tutanak taslağı kaydedildi.'),
              )
            }
          />
          <Button
            label="Tutanağı Kesinleştir"
            disabled={action.busy}
            onPress={() =>
              confirm(
                'Tutanak kesinleştirilsin mi?',
                'Kesinleştirilen tutanak daha sonra düzenlenemez. Bilgilerin doğru olduğundan emin olun.',
                () =>
                  void action.run(async () => {
                    await save();
                    const finalized = await inspections.finalize(inspection.id);
                    setRecord(finalized);
                    await invalidate(`inspection/${inspection.id}/record`);
                  }),
              )
            }
          />
        </>
      )}
    </>
  );
}
