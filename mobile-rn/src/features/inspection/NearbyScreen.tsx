import { Linking, Platform, View } from 'react-native';
import Constants from 'expo-constants';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import { useLocalSearchParams } from 'expo-router';
import { useRef, useState } from 'react';
import { positiveId } from '../../core/models';
import { inspections } from '../../core/services';
import { useResource } from '../../core/queries';
import { AppText, Button, Card, Gap } from '../../design/components';
import { Page, StateView, Tile } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import { useAction } from '../auth/useAction';
const darkMap = [
  {
    elementType: 'geometry',
    stylers: [
      {
        color: '#0b090e',
      },
    ],
  },
  {
    elementType: 'labels.text.fill',
    stylers: [
      {
        color: '#a9a0b5',
      },
    ],
  },
  {
    elementType: 'labels.text.stroke',
    stylers: [
      {
        color: '#0b090e',
      },
    ],
  },
  {
    featureType: 'administrative',
    elementType: 'geometry.stroke',
    stylers: [
      {
        color: '#302a39',
      },
    ],
  },
  {
    featureType: 'poi',
    elementType: 'geometry',
    stylers: [
      {
        color: '#151119',
      },
    ],
  },
  {
    featureType: 'poi',
    elementType: 'labels.text.fill',
    stylers: [
      {
        color: '#9d91aa',
      },
    ],
  },
  {
    featureType: 'road',
    elementType: 'geometry',
    stylers: [
      {
        color: '#211c27',
      },
    ],
  },
  {
    featureType: 'road',
    elementType: 'geometry.stroke',
    stylers: [
      {
        color: '#131016',
      },
    ],
  },
  {
    featureType: 'road.highway',
    elementType: 'geometry',
    stylers: [
      {
        color: '#34254a',
      },
    ],
  },
  {
    featureType: 'transit',
    elementType: 'geometry',
    stylers: [
      {
        color: '#18131d',
      },
    ],
  },
  {
    featureType: 'water',
    elementType: 'geometry',
    stylers: [
      {
        color: '#08070b',
      },
    ],
  },
  {
    featureType: 'water',
    elementType: 'labels.text.fill',
    stylers: [
      {
        color: '#62586e',
      },
    ],
  },
];
export default function NearbyScreen() {
  const { id: raw } = useLocalSearchParams<{ id: string }>(),
    id = positiveId(raw),
    { mode, colors } = useTheme(),
    action = useAction(),
    map = useRef<MapView>(null),
    [selected, setSelected] = useState(''),
    inspection = useResource(`inspection/${id}`, (signal) =>
      inspections.get(id, signal),
    ),
    services = useResource(`inspection/${id}/nearby`, (signal) =>
      inspections.nearby(id, signal),
    );
  const latitude = inspection.data?.locationLatitude,
    longitude = inspection.data?.locationLongitude,
    point = services.data?.find((service) => service.placeId === selected);
  const open = async (url: string) => {
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:')
      throw new Error('Harita bağlantısı geçersiz.');
    await Linking.openURL(url);
  };
  return (
    <Page
      title="Yakındaki Servisler"
      onRefresh={() => {
        void inspection.refetch();
        void services.refetch();
      }}
      refreshing={inspection.isRefetching || services.isRefetching}
    >
      {inspection.isPending ||
      services.isPending ||
      inspection.error ||
      services.error ? (
        <StateView
          loading={inspection.isPending || services.isPending}
          error={inspection.error ?? services.error}
          retry={() => {
            void inspection.refetch();
            void services.refetch();
          }}
        />
      ) : (
        <>
          {typeof latitude === 'number' &&
          typeof longitude === 'number' &&
          (Platform.OS === 'android'
            ? Constants.expoConfig?.extra?.androidMaps === true
            : Constants.expoConfig?.extra?.iosMaps === true) ? (
            <View style={{ height: 340, borderRadius: 24, overflow: 'hidden' }}>
              <MapView
                ref={map}
                style={{ flex: 1 }}
                provider={PROVIDER_GOOGLE}
                initialRegion={{
                  latitude,
                  longitude,
                  latitudeDelta: 0.08,
                  longitudeDelta: 0.08,
                }}
                customMapStyle={mode === 'dark' ? darkMap : []}
                showsUserLocation={false}
                onMapReady={() =>
                  map.current?.fitToCoordinates(
                    [{ latitude, longitude }, ...(services.data ?? [])],
                    {
                      edgePadding: { top: 50, left: 40, right: 40, bottom: 50 },
                      animated: false,
                    },
                  )
                }
                accessibilityLabel="Yakındaki servislerin haritası"
              >
                <Marker
                  coordinate={{ latitude, longitude }}
                  title="Analiz konumu"
                  pinColor={colors.primary}
                />
                {services.data?.map((service) => (
                  <Marker
                    key={service.placeId}
                    coordinate={{
                      latitude: service.latitude,
                      longitude: service.longitude,
                    }}
                    title={service.name}
                    description={service.address}
                    onPress={() => setSelected(service.placeId)}
                  />
                ))}
              </MapView>
            </View>
          ) : (
            <Card>
              <AppText>
                {typeof latitude === 'number' && typeof longitude === 'number'
                  ? 'Harita görüntülenemiyor. Servisleri listeden inceleyip haritada açabilirsiniz.'
                  : 'Bu analizde konum bilgisi bulunamadı.'}
              </AppText>
            </Card>
          )}
          {point && (
            <Card>
              <AppText variant="titleLarge">{point.name}</AppText>
              <AppText>{point.address}</AppText>
              <Gap />
              <Button
                label="Yol Tarifi"
                icon="map"
                onPress={() =>
                  void action.run(() =>
                    open(
                      `https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}&destination_place_id=${encodeURIComponent(point.placeId)}`,
                    ),
                  )
                }
              />
            </Card>
          )}
          {!services.data?.length && (
            <StateView empty="Yakında uygun servis bulunamadı." />
          )}
          {services.data?.map((service) => (
            <Tile
              key={service.placeId}
              title={service.name}
              subtitle={service.address}
              icon="tools"
              onPress={() => {
                setSelected(service.placeId);
                map.current?.animateToRegion({
                  latitude: service.latitude,
                  longitude: service.longitude,
                  latitudeDelta: 0.025,
                  longitudeDelta: 0.025,
                });
              }}
            >
              <Gap />
              <AppText>
                {service.distanceKm.toLocaleString('tr-TR', {
                  maximumFractionDigits: 1,
                })}{' '}
                km
                {service.rating
                  ? ` • ★ ${service.rating} (${service.userRatingCount ?? 0})`
                  : ''}
              </AppText>
              <Button
                label="Haritada Aç"
                variant="text"
                onPress={() =>
                  void action.run(() =>
                    open(
                      service.googleMapsUri ||
                        `https://www.google.com/maps/search/?api=1&query=${service.latitude},${service.longitude}&query_place_id=${encodeURIComponent(service.placeId)}`,
                    ),
                  )
                }
              />
            </Tile>
          ))}
        </>
      )}
    </Page>
  );
}
