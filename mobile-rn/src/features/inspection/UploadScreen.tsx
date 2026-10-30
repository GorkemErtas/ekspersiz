import { useEffect, useRef, useState } from 'react';
import { View } from 'react-native';
import { Image } from 'expo-image';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { inspections } from '../../core/services';
import { invalidate, useResource } from '../../core/queries';
import { positiveId } from '../../core/models';
import { pickPhoto, removePrepared } from '../../platform/images';
import { AppText, Button, Card, Gap, Icon } from '../../design/components';
import { Badge, Heading, Page, Select, StateView } from '../../design/layout';
import { useAction } from '../auth/useAction';
import { startAnalysis } from './analysisJobs';
import { damageAnalysisAvailable } from './CreateScreen';
type Photo = NonNullable<Awaited<ReturnType<typeof pickPhoto>>>;
export default function UploadScreen() {
  const { id: raw } = useLocalSearchParams<{ id: string }>(),
    id = positiveId(raw),
    router = useRouter(),
    action = useAction(),
    data = useResource(`inspection/${id}`, (signal) =>
      inspections.get(id, signal),
    ),
    [region, setRegion] = useState(''),
    [context, setContext] = useState<Photo | null>(null),
    [close, setClose] = useState<Photo | null>(null),
    [progress, setProgress] = useState(''),
    owned = useRef(new Set<string>()),
    alive = useRef(true),
    uploaded = useRef(new Set<string>());
  useEffect(() => {
    alive.current = true;
    uploaded.current.clear();
    const ownedFiles = owned.current;
    return () => {
      alive.current = false;
      for (const uri of ownedFiles) removePrepared(uri);
      ownedFiles.clear();
    };
  }, []);
  const pick = (general: boolean, camera: boolean) =>
    void action.run(async () => {
      const photo = await pickPhoto(camera);
      if (!photo) return;
      if (!alive.current) {
        removePrepared(photo.uri);
        return;
      }
      uploaded.current.clear();
      const previous = general ? context : close;
      if (previous) {
        removePrepared(previous.uri);
        owned.current.delete(previous.uri);
      }
      owned.current.add(photo.uri);
      if (general) setContext(photo);
      else setClose(photo);
    });
  const upload = async () => {
    let current = data.data;
    if (!current) throw new Error('İnceleme alınamadı.');
    if (!context) throw new Error('Önce genel görünüm fotoğrafını seçin.');
    if (!close) throw new Error('Yakın plan fotoğrafını seçin.');
    if (context.hash === close.hash)
      throw new Error(
        'Genel görünüm ve yakın detay için iki farklı fotoğraf kullanın.',
      );
    for (const [photo, general] of [
      [close, false],
      [context, true],
    ] as const) {
      if (photo && !uploaded.current.has(photo.uri)) {
        setProgress(
          general
            ? 'Genel görünüm fotoğrafı yükleniyor…'
            : 'Yakın plan fotoğrafı yükleniyor…',
        );
        current = await inspections.upload(id, photo.uri, general);
        uploaded.current.add(photo.uri);
      }
    }
    await invalidate(`inspection/${id}`, 'inspections');
    return current;
  };
  return (
    <Page title="Hasar Fotoğrafları">
      <Heading
        title="İki Fotoğrafla Daha Net Analiz"
        description="Aynı hasarın genel görünümünü ve yakın planını ekleyin."
        icon="camera"
      />
      {!damageAnalysisAvailable ? (
        <StateView empty="Hasar analizi şu anda kullanılamıyor." />
      ) : data.isPending || data.error ? (
        <StateView
          loading={data.isPending}
          error={data.error}
          retry={() => void data.refetch()}
        />
      ) : data.data?.status === 'COMPLETED' ||
        data.data?.status === 'PROCESSING' ? (
        <>
          <StateView empty="Mevcut analizin fotoğrafları korunur. Yeni fotoğraflarla devam etmek için yeni bir analiz oluşturun." />
          <Button
            label="Analizi Görüntüle"
            onPress={() => router.replace(`/inspection/${id}`)}
          />
          <Button
            label="Yeni Fotoğraf Denemesi"
            onPress={() =>
              router.replace({
                pathname: '/inspection/new',
                params: { vehicle: String(data.data?.vehicleId) },
              })
            }
          />
        </>
      ) : (
        <>
          {[
            [
              true,
              context,
              '1. Genel Görünüm',
              'Aracın hasarlı bölgesi ve çevresi aynı karede görünsün.',
            ],
            [
              false,
              close,
              '2. Yakın Plan',
              'Aynı hasarı yakından, net ve iyi ışıkta fotoğraflayın.',
            ],
          ].map(([general, photo, title, body]) => {
            const image = photo as Photo | null;
            return (
              <Card key={String(general)}>
                <AppText variant="titleLarge">{String(title)}</AppText>
                <Gap />
                <AppText>{String(body)}</AppText>
                <Gap />
                {image ? (
                  <Image
                    source={{ uri: image.uri }}
                    cachePolicy="none"
                    contentFit="contain"
                    accessibilityLabel={String(title)}
                    style={{ height: 210, width: '100%', borderRadius: 18 }}
                  />
                ) : (
                  <View
                    style={{
                      height: 140,
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: 12,
                    }}
                  >
                    <Icon name="camera" size={46} />
                    <AppText>
                      {general
                        ? data.data?.contextImagePath
                          ? 'Genel görünüm sunucuda kayıtlı'
                          : 'Genel görünüm fotoğrafı seçin'
                        : data.data?.imagePath
                          ? 'Yakın plan sunucuda kayıtlı'
                          : 'Yakın plan fotoğrafı seçin'}
                    </AppText>
                  </View>
                )}
                <Gap />
                <View
                  style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}
                >
                  <Button
                    label="Kamera"
                    icon="camera"
                    variant="outlined"
                    disabled={action.busy}
                    onPress={() => pick(Boolean(general), true)}
                  />
                  <Button
                    label="Galeri"
                    icon="gallery"
                    variant="outlined"
                    disabled={action.busy}
                    onPress={() => pick(Boolean(general), false)}
                  />
                </View>
              </Card>
            );
          })}
          <Select
            title="Hasarın bulunduğu araç bölgesi"
            value={region}
            onChange={setRegion}
            items={[
              { value: '', title: 'Otomatik / bilinmiyor' },
              { value: 'FRONT', title: 'Ön bölge' },
              { value: 'REAR', title: 'Arka bölge' },
            ]}
          />
          <Badge text="Genel görünüm + yakın plan" />
          <AppText>
            Plaka veya kişisel bilgileri kadraja almamaya dikkat edin. Görsel
            değerlendirme kesin ekspertiz değildir.
          </AppText>
          {progress && (
            <AppText accessibilityLiveRegion="polite">{progress}</AppText>
          )}
          <Button
            label="Fotoğrafların Uygunluğunu Kontrol Et"
            variant="outlined"
            disabled={action.busy}
            onPress={() =>
              void action.run(async () => {
                await upload();
                const [general, detail] = await Promise.all([
                  inspections.quality(id, true),
                  inspections.quality(id),
                ]);
                action.show(
                  `${general.message ?? ''}\n${detail.message ?? ''}`,
                );
              })
            }
          />
          <Button
            label="Analizi Başlat"
            icon="sparkles"
            loading={action.busy}
            onPress={() =>
              void action.run(async () => {
                await upload();
                setProgress('');
                startAnalysis(id, region as '' | 'FRONT' | 'REAR');
                router.replace({
                  pathname: '/inspection/analyzing',
                  params: { id: String(id) },
                });
              })
            }
          />
        </>
      )}
    </Page>
  );
}
