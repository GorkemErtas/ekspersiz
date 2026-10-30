import { useCallback, useEffect, useRef, useState } from 'react';
import * as Location from 'expo-location';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { api, session } from '../../core/runtime';
import { inspections, vehicles } from '../../core/services';
import { useResource, invalidate } from '../../core/queries';
import { positiveId } from '../../core/models';
import { AppText, Button, Card, Field, Gap } from '../../design/components';
import { Heading, Page, Select, StateView } from '../../design/layout';
import { useAction } from '../auth/useAction';
import { currentPosition, positionCity } from '../../platform/location';
import { Linking } from 'react-native';
export const damageAnalysisAvailable =
  process.env.EXPO_PUBLIC_DAMAGE_ANALYSIS_ENABLED !== 'false';
export default function CreateScreen() {
  const { vehicle } = useLocalSearchParams<{ vehicle?: string }>(),
    router = useRouter(),
    action = useAction(),
    alive = useRef(true),
    locationLock = useRef(false),
    locationController = useRef<AbortController | null>(null),
    [selection, setSelection] = useState(vehicle ?? ''),
    [city, setCity] = useState(''),
    [position, setPosition] = useState<{
      latitude: number;
      longitude: number;
    } | null>(null),
    [locationError, setLocationError] = useState(''),
    [locating, setLocating] = useState(damageAnalysisAvailable);
  const garage = useResource(
      'vehicles',
      vehicles.list,
      damageAnalysisAvailable,
    ),
    quota = useResource(
      'analysis-quota',
      () => api.request<{ remaining: number }>('/analysis-quota'),
      damageAnalysisAvailable,
    );
  const location = useCallback(async () => {
    if (locationLock.current) return;
    locationLock.current = true;
    const generation = session.getSnapshot().generation;
    const controller = new AbortController();
    locationController.current = controller;
    const untrack = session.track(controller);
    try {
      if (!(await Location.hasServicesEnabledAsync()))
        throw new Error('Telefonunuzun konum servisi kapalı.');
      const permission = await Location.requestForegroundPermissionsAsync();
      if (!permission.granted)
        throw new Error(
          'Konum izni verilmedi. Cihaz ayarlarından izin verebilirsiniz.',
        );
      const point = await currentPosition(controller.signal);
      session.check(generation);
      if (!alive.current) return;
      setPosition(point.coords);
      try {
        const addresses = await positionCity(point.coords);
        session.check(generation);
        const address = addresses[0];
        if (alive.current) setCity(address?.region ?? address?.city ?? '');
      } catch {
        if (alive.current)
          setLocationError('Şehir adı belirlenemedi. Şehir adını girin.');
      }
    } catch (error) {
      if (alive.current)
        setLocationError(
          error instanceof Error ? error.message : 'Konum alınamadı.',
        );
    } finally {
      untrack();
      if (locationController.current === controller)
        locationController.current = null;
      locationLock.current = false;
      if (alive.current) setLocating(false);
    }
  }, []);
  useEffect(() => {
    alive.current = true;
    if (damageAnalysisAvailable) void Promise.resolve().then(location);
    return () => {
      alive.current = false;
      locationController.current?.abort();
    };
  }, [location]);
  return (
    <Page title="Yeni Hasar Analizi">
      <Heading
        title="Aracınızı Seçin"
        description="Genel görünüm ve yakın plan fotoğraflarıyla hasarı değerlendirin."
        icon="sparkles"
      />
      {!damageAnalysisAvailable ? (
        <StateView empty="Hasar analizi şu anda kullanılamıyor. Geçmiş raporlarınızı görüntüleyebilirsiniz." />
      ) : garage.isPending || garage.error ? (
        <StateView
          loading={garage.isPending}
          error={garage.error}
          retry={() => void garage.refetch()}
        />
      ) : !garage.data?.length ? (
        <>
          <StateView empty="Analiz başlatmak için önce bir araç ekleyin." />
          <Button
            label="Araç Ekle"
            onPress={() => router.push('/vehicle/new')}
          />
        </>
      ) : (
        <>
          <Card>
            <Select
              title="Analiz edilecek araç"
              value={
                selection ||
                String(
                  garage.data.find((v) => v.primaryVehicle)?.id ??
                    garage.data[0]!.id,
                )
              }
              onChange={setSelection}
              items={garage.data.map((v) => ({
                value: String(v.id),
                title: `${v.plate} • ${v.brand} ${v.model}`,
              }))}
            />
            <Gap />
            <AppText>
              {quota.data
                ? `Kalan analiz hakkınız: ${quota.data.remaining}`
                : 'Analiz haklarınız işlem sırasında sunucudan kontrol edilir.'}
            </AppText>
            <Button
              label="Krediler ve Paketler"
              variant="text"
              onPress={() => router.push('/billing')}
            />
          </Card>
          <Card>
            <AppText variant="titleLarge">Analiz Konumu</AppText>
            <Gap />
            <Field
              label="Şehir"
              icon="map"
              value={city}
              onChangeText={setCity}
              maxLength={80}
            />
            <Gap />
            <AppText>
              {position
                ? 'Konum bilgisi alındı.'
                : 'Yakındaki servisleri göstermek için konum gereklidir.'}
            </AppText>
            {locationError && (
              <>
                <AppText accessibilityRole="alert">{locationError}</AppText>
                <Button
                  label="Ayarları Aç"
                  variant="text"
                  onPress={() => void Linking.openSettings()}
                />
              </>
            )}
            <Button
              label="Konumu Yenile"
              icon="map"
              variant="text"
              loading={locating}
              onPress={() => {
                setLocating(true);
                setLocationError('');
                void location();
              }}
            />
          </Card>
          <AppText>
            Fotoğraf analizi profesyonel ekspertiz yerine geçmez. Kesin hasar ve
            maliyet fiziksel incelemeyle belirlenir.
          </AppText>
          <Button
            label="Fotoğraflara Devam Et"
            icon="camera"
            loading={action.busy}
            disabled={locating}
            onPress={() =>
              void action.run(async () => {
                if (!position || !city.trim())
                  throw new Error('Konumunuzu ve şehir adını kontrol edin.');
                const id = positiveId(
                  selection ||
                    garage.data?.find((v) => v.primaryVehicle)?.id ||
                    garage.data?.[0]?.id,
                );
                const record = await inspections.create(
                  id,
                  city,
                  position.latitude,
                  position.longitude,
                );
                await invalidate('inspections');
                router.replace({
                  pathname: '/inspection/upload',
                  params: { id: String(record.id) },
                });
              })
            }
          />
        </>
      )}
    </Page>
  );
}
