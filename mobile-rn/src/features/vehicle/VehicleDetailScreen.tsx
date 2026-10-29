import { useLocalSearchParams, useRouter } from 'expo-router';
import { vehicles } from '../../core/services';
import { positiveId } from '../../core/models';
import { invalidate, useResource } from '../../core/queries';
import { dateText, label, money, number } from '../../core/labels';
import { AppText, Button, Card, Gap } from '../../design/components';
import {
  Badge,
  Heading,
  Page,
  Section,
  StateView,
  Tile,
  confirm,
} from '../../design/layout';
import { useAction } from '../auth/useAction';

export default function VehicleDetailScreen() {
  const { id: raw } = useLocalSearchParams<{ id: string }>();
  const id = positiveId(raw);
  const router = useRouter();
  const action = useAction();
  const vehicle = useResource(`vehicles/${id}`, (s) => vehicles.get(id, s)),
    overview = useResource(`vehicles/${id}/overview`, (s) =>
      vehicles.overview(id, s),
    ),
    maintenance = useResource(`vehicles/${id}/maintenance`, (s) =>
      vehicles.maintenance(id, s),
    ),
    reminders = useResource(`vehicles/${id}/reminders`, (s) =>
      vehicles.reminders(id, s),
    ),
    history = useResource(`vehicles/${id}/history`, (s) =>
      vehicles.history(id, s),
    );
  const form = (kind: 'maintenance' | 'reminders', edit?: number) =>
    router.push({
      pathname: '/vehicle/tracking',
      params: {
        vehicle: String(id),
        kind,
        ...(edit ? { edit: String(edit) } : {}),
      },
    });
  const remove = (kind: 'maintenance' | 'reminders', recordId: number) =>
    confirm(
      'Kayıt silinsin mi?',
      'Bu işlem geri alınamaz.',
      () =>
        void action.run(
          () => vehicles.deleteTracking(id, kind, recordId),
          () => void invalidate(`vehicles/${id}`),
        ),
      true,
    );
  return (
    <Page
      title={
        vehicle.data
          ? `${vehicle.data.brand} ${vehicle.data.model}`
          : 'Araç Detayı'
      }
      onRefresh={() => void invalidate(`vehicles/${id}`)}
      refreshing={vehicle.isRefetching}
    >
      {!vehicle.data ? (
        <StateView
          loading={vehicle.isPending}
          error={vehicle.error}
          retry={() => void vehicle.refetch()}
        />
      ) : (
        <>
          <Heading
            title={`${vehicle.data.brand} ${vehicle.data.model}`}
            description={`${vehicle.data.plate} • ${vehicle.data.modelYear} • ${number(vehicle.data.mileage)} km`}
          />
          <Button
            label="AI Hasar Analizi"
            icon="sparkles"
            onPress={() =>
              router.push({
                pathname: '/inspection/new',
                params: { vehicle: String(id) },
              })
            }
          />
          <Button
            label="Aracı Düzenle"
            icon="edit"
            variant="outlined"
            onPress={() =>
              router.push({
                pathname: '/vehicle/new',
                params: { edit: String(id) },
              })
            }
          />
          {overview.data ? (
            <Card>
              <AppText variant="titleMedium">Araç takip durumu</AppText>
              <Gap />
              <Badge
                text={label(overview.data.trackingStatus)}
                status={overview.data.trackingStatus}
              />
              <Gap />
              <AppText>{overview.data.disclaimer}</AppText>
            </Card>
          ) : (
            <StateView
              loading={overview.isPending}
              error={overview.error}
              retry={() => void overview.refetch()}
            />
          )}
          <Section
            title="Bakım Kayıtları"
            action="Bakım Ekle"
            onPress={() => form('maintenance')}
          />
          {maintenance.error ? (
            <StateView
              error={maintenance.error}
              retry={() => void maintenance.refetch()}
            />
          ) : maintenance.data?.length ? (
            maintenance.data.map((item) => (
              <Tile
                key={item.id}
                icon="tools"
                title={label(item.maintenanceType)}
                subtitle={`${dateText(item.maintenanceDate)} • ${number(item.mileage)} km${item.cost != null ? ` • ${money(item.cost)}` : ''}`}
              >
                {item.note && <AppText>{item.note}</AppText>}
                {(item.nextRecommendedDate ||
                  item.nextRecommendedMileage != null) && (
                  <AppText>
                    Sonraki bakım: {dateText(item.nextRecommendedDate)} •{' '}
                    {item.nextRecommendedMileage ?? '—'} km
                  </AppText>
                )}
                <Button
                  label="Düzenle"
                  variant="text"
                  onPress={() => form('maintenance', item.id)}
                />
                <Button
                  label="Sil"
                  variant="text"
                  disabled={action.busy}
                  onPress={() => remove('maintenance', item.id)}
                />
              </Tile>
            ))
          ) : (
            <AppText>Henüz bakım kaydı yok.</AppText>
          )}
          <Section
            title="Hatırlatmalar"
            action="Hatırlatma Ekle"
            onPress={() => form('reminders')}
          />
          {reminders.error ? (
            <StateView
              error={reminders.error}
              retry={() => void reminders.refetch()}
            />
          ) : reminders.data?.length ? (
            reminders.data.map((item) => (
              <Tile
                key={item.id}
                icon="calendar"
                title={item.title ?? label(item.reminderType)}
                subtitle={`${dateText(item.dueDate)}${item.dueMileage != null ? ` • ${number(item.dueMileage)} km` : ''}`}
              >
                <Gap />
                <Badge text={label(item.status)} status={item.status} />
                {item.note && <AppText>{item.note}</AppText>}
                <Button
                  label={
                    item.status === 'COMPLETED' ? 'Yeniden Aç' : 'Tamamlandı'
                  }
                  variant="text"
                  disabled={action.busy}
                  onPress={() =>
                    void action.run(
                      () =>
                        vehicles.complete(
                          id,
                          item.id,
                          item.status !== 'COMPLETED',
                        ),
                      () => void invalidate(`vehicles/${id}`, 'notifications'),
                    )
                  }
                />
                <Button
                  label="Düzenle"
                  variant="text"
                  onPress={() => form('reminders', item.id)}
                />
                <Button
                  label="Sil"
                  variant="text"
                  onPress={() => remove('reminders', item.id)}
                />
              </Tile>
            ))
          ) : (
            <AppText>Henüz hatırlatma yok.</AppText>
          )}
          <Section title="Araç Geçmişi" />
          {history.error ? (
            <StateView
              error={history.error}
              retry={() => void history.refetch()}
            />
          ) : history.data?.length ? (
            history.data.map((item, index) => (
              <Card key={index}>
                <AppText variant="titleMedium">{item.title}</AppText>
                <AppText>{item.description}</AppText>
                <AppText variant="bodySmall">
                  {dateText(item.occurredAt)}
                </AppText>
              </Card>
            ))
          ) : (
            <AppText>Henüz geçmiş kaydı yok.</AppText>
          )}
        </>
      )}
    </Page>
  );
}
