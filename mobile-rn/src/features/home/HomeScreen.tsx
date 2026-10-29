import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useSession } from '../../core/runtime';
import { inspections, notifications, vehicles } from '../../core/services';
import { useResource } from '../../core/queries';
import { AppText, Card, Gap, Icon, IconButton } from '../../design/components';
import {
  Badge,
  Columns,
  Page,
  Section,
  StateView,
  Tile,
} from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import PrimaryVehicleSheet from './PrimaryVehicleSheet';
import {
  AnalysisHero,
  TrackingPeek,
  PrimaryCard,
  LatestCard,
} from './DashboardCards';
export default function HomeScreen({
  onVehicles,
  onHistory,
  onProfile,
}: {
  onVehicles: () => void;
  onHistory: () => void;
  onProfile: () => void;
}) {
  const { profile, workspace } = useSession(),
    router = useRouter(),
    { colors, mode, toggle } = useTheme(),
    [choosing, setChoosing] = useState(false);
  const garage = useResource('vehicles', vehicles.list),
    history = useResource('inspections', inspections.list),
    unread = useResource('notifications/unread', notifications.unread);
  const primary =
      garage.data?.find((v) => v.primaryVehicle) ?? garage.data?.[0],
    overview = useResource(
      `vehicles/${primary?.id}/overview`,
      (signal) => vehicles.overview(primary!.id, signal),
      !!primary,
    );
  const newest = history.data
    ?.slice()
    .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))[0];
  const refresh = () => {
    void garage.refetch();
    void history.refetch();
    void unread.refetch();
    if (primary) void overview.refetch();
  };
  const parts = profile?.fullName.trim().split(/\s+/) ?? [],
    initials =
      `${parts[0]?.[0] ?? 'E'}${parts.length > 1 ? (parts.at(-1)?.[0] ?? '') : ''}`.toLocaleUpperCase(
        'tr-TR',
      );
  return (
    <Page
      title="Ana Sayfa"
      back={false}
      embedded
      toolbar={false}
      onRefresh={refresh}
      refreshing={garage.isRefetching || history.isRefetching}
      contentBottom={200}
    >
      <View
        style={{ flexDirection: 'row', alignItems: 'center', paddingBottom: 7 }}
      >
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Profili aç"
          onPress={onProfile}
        >
          <LinearGradient
            colors={['#8B5CF6', '#C084FC']}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={{
              width: 50,
              height: 50,
              borderRadius: 25,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <AppText style={{ color: '#fff', fontWeight: '900', fontSize: 15 }}>
              {initials}
            </AppText>
          </LinearGradient>
        </Pressable>
        <View style={{ flex: 1, marginLeft: 14, marginRight: 8 }}>
          <AppText
            variant="titleLarge"
            numberOfLines={1}
            style={{ fontWeight: '900', letterSpacing: -0.4 }}
          >
            EksperSiz
          </AppText>
          <View style={{ height: 2 }} />
          <AppText
            variant="bodySmall"
            numberOfLines={1}
            style={{ fontWeight: '600' }}
          >
            AI destekli araç asistanınız
          </AppText>
        </View>
        <IconButton
          surface
          label={mode === 'dark' ? 'Açık tema' : 'Koyu tema'}
          icon={mode === 'dark' ? 'light' : 'dark'}
          onPress={toggle}
        />
        <View style={{ width: 8 }} />
        <View>
          <IconButton
            surface
            label={`Bildirimler, ${unread.data?.unreadCount ?? 0} okunmamış`}
            icon="bell"
            onPress={() => router.push('/notifications')}
          />
          {!!unread.data?.unreadCount && (
            <View
              style={{
                position: 'absolute',
                right: 5,
                top: 5,
                minWidth: 17,
                height: 17,
                paddingHorizontal: 4,
                borderRadius: 9,
                backgroundColor: colors.error,
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <AppText
                style={{
                  color: '#fff',
                  fontSize: 9,
                  lineHeight: 12,
                  fontWeight: '900',
                }}
              >
                {unread.data.unreadCount > 99 ? '99+' : unread.data.unreadCount}
              </AppText>
            </View>
          )}
        </View>
      </View>
      {workspace === 'BUSINESS' && profile?.businessAccount && (
        <Card>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <Icon name="business" color={colors.primary} size={28} />
            <View style={{ flex: 1 }}>
              <AppText variant="titleMedium" style={{ fontWeight: '900' }}>
                {profile.businessAccount.companyName}
              </AppText>
              <AppText variant="bodySmall">
                Şirketin ortak araçları ve analiz geçmişi gösteriliyor.
              </AppText>
            </View>
            <Badge
              text={
                profile.businessAccount.role === 'OWNER'
                  ? 'Şirket sahibi'
                  : 'Üye'
              }
              compact
            />
          </View>
        </Card>
      )}
      <AnalysisHero onPress={() => router.push('/inspection/new')} />
      {overview.data && (
        <TrackingPeek
          overview={overview.data}
          onPress={() => router.push(`/vehicle/${primary!.id}`)}
        />
      )}
      {overview.error && (
        <StateView
          error={overview.error}
          retry={() => void overview.refetch()}
        />
      )}
      <Columns
        first={
          <>
            <Section
              title={
                workspace === 'BUSINESS' ? 'Şirketin Ana Aracı' : 'Ana Araç'
              }
              action={
                workspace === 'BUSINESS' ? 'Şirket Araçları' : 'Araçlarım'
              }
              onPress={() =>
                garage.data && garage.data.length > 1
                  ? setChoosing(true)
                  : onVehicles()
              }
            />
            <Gap />
            {garage.isPending || garage.error ? (
              <StateView
                loading={garage.isPending}
                error={garage.error}
                retry={() => void garage.refetch()}
              />
            ) : primary ? (
              <PrimaryCard
                vehicle={primary}
                onPress={() => setChoosing(true)}
              />
            ) : (
              <Tile
                title="Garajınız henüz boş"
                subtitle="İlk aracınızı ekleyerek başlayın."
                icon="add"
                onPress={() => router.push('/vehicle/new')}
              />
            )}
          </>
        }
        second={
          <>
            <Section
              title={
                workspace === 'BUSINESS' ? 'Şirketin Son Analizi' : 'Son Analiz'
              }
              action="Geçmiş"
              onPress={onHistory}
            />
            <Gap />
            {history.isPending || history.error ? (
              <StateView
                loading={history.isPending}
                error={history.error}
                retry={() => void history.refetch()}
              />
            ) : newest ? (
              <LatestCard
                inspection={newest}
                onPress={() => router.push(`/inspection/${newest.id}`)}
              />
            ) : (
              <StateView empty="Henüz bir analiz yapılmadı." />
            )}
          </>
        }
      />
      <PrimaryVehicleSheet
        items={garage.data ?? []}
        selected={primary?.id}
        visible={choosing}
        onClose={() => setChoosing(false)}
      />
    </Page>
  );
}
