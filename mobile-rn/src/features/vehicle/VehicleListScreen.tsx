import { dimensions, radius, spacing } from '../../design/tokens';
import { useState } from 'react';
import { Alert, FlatList, View } from 'react-native';
import { useRouter } from 'expo-router';
import { billingApi, vehicles } from '../../core/services';
import { useResource, invalidate } from '../../core/queries';
import { useSession } from '../../core/runtime';
import type { Vehicle } from '../../core/models';
import { number } from '../../core/labels';
import {
  AppText,
  Button,
  Card,
  Icon,
  IconButton,
  Field,
  type IconName,
} from '../../design/components';
import { layoutStyles, Page, StateView } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import { Sheet } from '../../design/Sheet';
import { TouchSurface } from '../../design/TouchSurface';
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
        maxWidth: '100%',
        alignItems: 'center',
        gap: 6,
        paddingHorizontal: 10,
        paddingVertical: 6,
        borderRadius: radius.pill,
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
          flexShrink: 1,
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
    [menu, setMenu] = useState<Vehicle | null>(null);
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
      <View style={{ flex: 1, minHeight: 0 }}>
        {data.isPending || data.error ? (
          <View style={{ padding: spacing.page }}>
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
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="on-drag"
            keyExtractor={(item) => String(item.id)}
            contentContainerStyle={layoutStyles.listContent}
            refreshing={data.isRefetching}
            onRefresh={() => {
              void data.refetch();
              void credits.refetch();
            }}
            ListHeaderComponent={
              data.data?.length ? (
                <View style={{ paddingBottom: 4 }}>
                  {searching && (
                    <View style={{ paddingBottom: spacing.m }}>
                      <Field
                        label="Araç ara"
                        icon="search"
                        value={search}
                        onChangeText={setSearch}
                        autoFocus
                      />
                    </View>
                  )}
                  <AppText
                    variant="headlineSmall"
                    style={{ fontWeight: '900' }}
                  >
                    {workspace === 'BUSINESS'
                      ? profile?.businessAccount?.companyName
                      : 'Garajınız'}
                  </AppText>
                  <View style={{ height: spacing.s }} />
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
              <TouchSurface
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
                        width: dimensions.touch,
                        height: dimensions.touch,
                        borderRadius: radius.small,
                        alignItems: 'center',
                        justifyContent: 'center',
                        backgroundColor: colors.primaryContainer,
                      }}
                    >
                      <Icon name="car" size={24} color={colors.primary} />
                    </View>
                    <AppText
                      variant="titleMedium"
                      style={{ flex: 1, minWidth: 0, fontWeight: '800' }}
                    >
                      {item.brand} {item.model}
                    </AppText>
                    <TouchSurface
                      accessibilityRole="button"
                      accessibilityLabel={`${item.plate} araç işlemleri`}
                      onPress={(event) => {
                        event.stopPropagation();
                        setMenu(item);
                      }}
                      style={{
                        width: dimensions.touch,
                        height: dimensions.touch,
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Icon name="more" />
                    </TouchSurface>
                  </View>
                  <View style={{ height: spacing.m }} />
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
                    style={{
                      flexDirection: 'row',
                      alignItems: 'center',
                      gap: 6,
                    }}
                  >
                    <Icon name="speed" size={17} color={colors.secondaryText} />
                    <AppText style={{ fontWeight: '600', flexShrink: 1 }}>
                      {number(item.mileage)} km
                    </AppText>
                  </View>
                </Card>
              </TouchSurface>
            )}
          />
        )}
      </View>
      <View
        style={{ paddingHorizontal: spacing.page, paddingVertical: spacing.s }}
      >
        <Button
          label="Araç Ekle"
          icon="add"
          onPress={() => router.push('/vehicle/new')}
        />
      </View>
      <Sheet
        visible={!!menu}
        title={menu ? menu.plate + ' · Araç işlemleri' : 'Araç işlemleri'}
        onClose={() => setMenu(null)}
      >
        {menu && (
          <View
            style={{
              gap: 8,
              paddingBottom: 8,
            }}
          >
            {[
              {
                title: 'Düzenle',
                icon: 'edit' as const,
                run: () =>
                  router.push({
                    pathname: '/vehicle/new',
                    params: { edit: String(menu.id) },
                  }),
              },
              {
                title: 'Garajdan Kaldır',
                icon: 'delete' as const,
                run: () => remove(menu),
              },
            ].map((item, index) => (
              <TouchSurface
                key={item.title}
                accessibilityRole="button"
                onPress={(event) => {
                  event.stopPropagation();
                  setMenu(null);
                  item.run();
                }}
                style={{
                  minHeight: 48,
                  paddingVertical: 12,
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
                  style={{ color: index ? colors.error : colors.text, flex: 1 }}
                >
                  {item.title}
                </AppText>
              </TouchSurface>
            ))}
          </View>
        )}
      </Sheet>
    </Page>
  );
}
