import { useRef, useState, type ComponentRef } from 'react';
import {
  Alert,
  FlatList,
  Modal,
  Pressable,
  View,
  useWindowDimensions,
} from 'react-native';
import { useRouter } from 'expo-router';
import { billingApi, vehicles } from '../../core/services';
import { useResource, invalidate } from '../../core/queries';
import { useSession } from '../../core/runtime';
import type { Vehicle } from '../../core/models';
import { number } from '../../core/labels';
import {
  AppText,
  Card,
  Icon,
  IconButton,
  Field,
  type IconName,
} from '../../design/components';
import { Page, StateView } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import { useAction } from '../auth/useAction';
function Chip({
  text,
  icon,
  emphasized = false,
}: {
  text: string;
  icon: IconName;
  emphasized?: boolean;
}) {
  const { colors } = useTheme();
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 6,
        paddingHorizontal: 10,
        paddingVertical: 6,
        borderRadius: 99,
        backgroundColor: emphasized ? colors.primaryContainer : colors.high,
      }}
    >
      <Icon
        name={icon}
        size={14}
        color={emphasized ? colors.primary : colors.secondaryText}
      />
      <AppText
        variant="bodySmall"
        style={{
          fontWeight: '700',
          color: emphasized ? colors.primary : colors.secondaryText,
        }}
      >
        {text}
      </AppText>
    </View>
  );
}
export default function VehicleListScreen({
  embedded = false,
}: {
  embedded?: boolean;
}) {
  const router = useRouter(),
    [searching, setSearching] = useState(false),
    [search, setSearch] = useState(''),
    { profile, workspace } = useSession(),
    { colors } = useTheme(),
    action = useAction(),
    window = useWindowDimensions(),
    anchors = useRef(new Map<number, ComponentRef<typeof View>>()),
    [menu, setMenu] = useState<{
      vehicle: Vehicle;
      x: number;
      y: number;
    } | null>(null);
  const data = useResource('vehicles', vehicles.list),
    credits = useResource('credits', billingApi.credits),
    account =
      workspace === 'BUSINESS' ? credits.data?.company : credits.data?.personal;
  const remove = (vehicle: Vehicle) =>
    Alert.alert(
      'Araç garajdan kaldırılsın mı?',
      `${vehicle.brand} ${vehicle.model} garajınızdan kaldırılacak. Devam etmek istiyor musunuz?`,
      [
        { text: 'Vazgeç', style: 'cancel' },
        {
          text: 'Garajdan Kaldır',
          style: 'destructive',
          onPress: () =>
            void action.run(async () => {
              await vehicles.delete(vehicle.id);
              await invalidate('vehicles', 'credits');
            }),
        },
      ],
    );
  return (
    <Page
      title={workspace === 'BUSINESS' ? 'Şirket Araçları' : 'Araçlarım'}
      back={!embedded}
      embedded={embedded}
      scroll={false}
      actions={
        <IconButton
          label={searching ? 'Aramayı kapat' : 'Araçlarda Ara'}
          icon={searching ? 'close' : 'search'}
          disabled={!data.data?.length}
          onPress={() => {
            setSearching((value) => !value);
            setSearch('');
          }}
        />
      }
    >
      {data.isPending || data.error ? (
        <View style={{ padding: 18 }}>
          <StateView
            loading={data.isPending}
            error={data.error}
            retry={() => void data.refetch()}
          />
        </View>
      ) : (
        <FlatList
          data={data.data?.filter((vehicle) =>
            `${vehicle.plate} ${vehicle.brand} ${vehicle.model} ${vehicle.modelYear}`
              .toLocaleLowerCase('tr-TR')
              .includes(search.trim().toLocaleLowerCase('tr-TR')),
          )}
          keyExtractor={(item) => String(item.id)}
          contentContainerStyle={{
            paddingHorizontal: 18,
            paddingTop: 15,
            gap: 14,
            paddingBottom: 120,
            maxWidth: 1100,
            width: '100%',
            alignSelf: 'center',
          }}
          refreshing={data.isRefetching}
          onRefresh={() => {
            void data.refetch();
            void credits.refetch();
          }}
          ListHeaderComponent={
            data.data?.length ? (
              <View style={{ paddingBottom: 4 }}>
                {searching && (
                  <View style={{ paddingBottom: 14 }}>
                    <Field
                      label="Araç ara"
                      icon="search"
                      value={search}
                      onChangeText={setSearch}
                      autoFocus
                    />
                  </View>
                )}
                <AppText variant="headlineSmall" style={{ fontWeight: '900' }}>
                  {workspace === 'BUSINESS'
                    ? profile?.businessAccount?.companyName
                    : 'Garajınız'}
                </AppText>
                <View style={{ height: 6 }} />
                <AppText
                  variant="bodyLarge"
                  style={{ lineHeight: 23.2, color: colors.secondaryText }}
                >
                  {workspace === 'BUSINESS'
                    ? 'Şirket üyelerinin ortak kullandığı araçları buradan yönetebilirsiniz. Business 10 ortak slot içerir; ek slotlar kalıcıdır.'
                    : 'Kayıtlı araçlarınızı buradan görüntüleyebilir, düzenleyebilir ve yönetebilirsiniz.'}
                </AppText>
                <View style={{ height: 20 }} />
                <View style={{ alignSelf: 'flex-start' }}>
                  <Chip
                    emphasized
                    icon="garage"
                    text={
                      account
                        ? `${data.data.length} / ${account.totalSlots} araç slotu · ${Math.max(0, account.totalSlots - data.data.length)} boş`
                        : `${data.data.length} kayıtlı araç`
                    }
                  />
                </View>
              </View>
            ) : undefined
          }
          ListEmptyComponent={
            <StateView
              empty={
                search.trim()
                  ? 'Aramanıza uygun araç bulunamadı.'
                  : workspace === 'BUSINESS'
                    ? 'Şirket filosu henüz boş. İlk şirket aracını ekleyin.'
                    : 'Garajınız henüz boş. AI destekli hasar analizi başlatmak için önce aracınızı kaydedin.'
              }
            />
          }
          renderItem={({ item }) => (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={`${item.brand} ${item.model}, ${item.plate}`}
              onPress={() => router.push(`/vehicle/${item.id}`)}
            >
              <Card>
                <View
                  style={{
                    flexDirection: 'row',
                    alignItems: 'flex-start',
                    gap: 12,
                  }}
                >
                  <View
                    style={{
                      width: 48,
                      height: 48,
                      borderRadius: 16,
                      alignItems: 'center',
                      justifyContent: 'center',
                      backgroundColor: colors.primaryContainer,
                    }}
                  >
                    <Icon name="car" size={24} color={colors.primary} />
                  </View>
                  <AppText
                    variant="titleMedium"
                    style={{ flex: 1, fontWeight: '800' }}
                  >
                    {item.brand} {item.model}
                  </AppText>
                  <Pressable
                    ref={(element) => {
                      if (element) anchors.current.set(item.id, element);
                    }}
                    accessibilityRole="button"
                    accessibilityLabel={`${item.plate} araç işlemleri`}
                    onPress={(event) => {
                      event.stopPropagation();
                      anchors.current.get(item.id)?.measureInWindow((x, y) =>
                        setMenu({
                          vehicle: item,
                          x: Math.min(x, window.width - 220),
                          y: Math.min(y + 36, window.height - 180),
                        }),
                      );
                    }}
                    style={{
                      width: 48,
                      height: 48,
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <Icon name="more" />
                  </Pressable>
                </View>
                <View style={{ height: 15 }} />
                <View
                  style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}
                >
                  <Chip icon="badge" text={item.plate} />
                  <Chip icon="calendar" text={String(item.modelYear)} />
                  {item.primaryVehicle && (
                    <Chip emphasized icon="star" text="Ana araç" />
                  )}
                </View>
                <View style={{ height: 12 }} />
                <View
                  style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}
                >
                  <Icon name="speed" size={17} color={colors.secondaryText} />
                  <AppText style={{ fontWeight: '600' }}>
                    {number(item.mileage)} km
                  </AppText>
                </View>
              </Card>
            </Pressable>
          )}
        />
      )}
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Araç Ekle"
        onPress={() => router.push('/vehicle/new')}
        style={{
          position: 'absolute',
          right: 16,
          bottom: 2,
          minHeight: 56,
          paddingHorizontal: 16,
          borderRadius: 16,
          backgroundColor: colors.primary,
          flexDirection: 'row',
          alignItems: 'center',
          gap: 8,
        }}
      >
        <Icon name="add" size={24} color={colors.onPrimary} />
        <AppText variant="labelLarge" style={{ color: colors.onPrimary }}>
          Araç Ekle
        </AppText>
      </Pressable>
      <Modal
        visible={!!menu}
        transparent
        animationType="fade"
        onRequestClose={() => setMenu(null)}
      >
        <Pressable
          accessibilityLabel="Menüyü kapat"
          onPress={() => setMenu(null)}
          style={{ flex: 1 }}
        >
          {menu && (
            <View
              accessibilityViewIsModal
              style={{
                position: 'absolute',
                left: Math.max(12, menu.x),
                top: menu.y,
                width: 208,
                paddingVertical: 8,
                borderRadius: 12,
                backgroundColor: colors.high,
                boxShadow: '0 4px 24px #00000066',
              }}
            >
              {[
                {
                  title: 'Düzenle',
                  icon: 'edit' as const,
                  run: () =>
                    router.push({
                      pathname: '/vehicle/new',
                      params: { edit: String(menu.vehicle.id) },
                    }),
                },
                {
                  title: 'Garajdan Kaldır',
                  icon: 'delete' as const,
                  run: () => remove(menu.vehicle),
                },
              ].map((item, index) => (
                <Pressable
                  key={item.title}
                  accessibilityRole="menuitem"
                  onPress={(event) => {
                    event.stopPropagation();
                    setMenu(null);
                    item.run();
                  }}
                  style={{
                    minHeight: 48,
                    flexDirection: 'row',
                    alignItems: 'center',
                    gap: 12,
                    paddingHorizontal: 16,
                  }}
                >
                  <Icon
                    name={item.icon}
                    color={index ? colors.error : colors.text}
                    size={20}
                  />
                  <AppText
                    style={{ color: index ? colors.error : colors.text }}
                  >
                    {item.title}
                  </AppText>
                </Pressable>
              ))}
            </View>
          )}
        </Pressable>
      </Modal>
    </Page>
  );
}
