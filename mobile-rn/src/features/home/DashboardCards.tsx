import { Pressable, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import type { Inspection, Vehicle, VehicleOverview } from '../../core/models';
import { label, number } from '../../core/labels';
import { AppText, Card, Icon } from '../../design/components';
import { Badge } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import { gradients } from '../../design/tokens';
export function AnalysisHero({ onPress }: { onPress: () => void }) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel="Yeni Analiz Başlat"
      onPress={onPress}
    >
      <LinearGradient
        colors={gradients.deep}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={{
          padding: 18,
          borderRadius: 24,
          overflow: 'hidden',
          boxShadow: '0 8px 24px #6D28D92E',
        }}
      >
        <View
          style={{
            position: 'absolute',
            right: -10,
            top: -20,
            width: 132,
            height: 132,
            borderRadius: 66,
            backgroundColor: '#FFFFFF12',
          }}
        />
        <View
          style={{
            width: 42,
            height: 42,
            borderRadius: 14,
            backgroundColor: '#FFFFFF24',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="sparkles" size={22} color="#fff" />
        </View>
        <View style={{ height: 15 }} />
        <AppText
          variant="headlineSmall"
          style={{ color: '#fff', fontWeight: '900' }}
        >
          AI Hasar Analizi
        </AppText>
        <View style={{ height: 7 }} />
        <AppText style={{ color: '#FFFFFFD1', lineHeight: 19.6 }}>
          Hasarlı bölgenin fotoğrafını yükleyin, AI destekli raporunuzu
          oluşturun.
        </AppText>
        <View style={{ height: 18 }} />
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <AppText
            variant="labelLarge"
            style={{
              color: '#fff',
              fontWeight: '900',
              fontSize: 14,
              lineHeight: 20,
            }}
          >
            Yeni Analiz Başlat
          </AppText>
          <Icon name="forward" size={19} color="#fff" />
        </View>
      </LinearGradient>
    </Pressable>
  );
}
export function TrackingPeek({
  overview,
  onPress,
}: {
  overview: VehicleOverview;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel="Araç takibi"
      onPress={onPress}
    >
      <Card>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
          <Icon name="health" size={24} />
          <View style={{ flex: 1 }}>
            <AppText variant="titleSmall" style={{ fontWeight: '900' }}>
              Araç takibi
            </AppText>
            <View style={{ height: 4 }} />
            {overview.upcomingReminders.length ? (
              overview.upcomingReminders.slice(0, 2).map((reminder) => (
                <AppText
                  key={reminder.id}
                  numberOfLines={1}
                  style={{ paddingTop: 2 }}
                >
                  {reminder.title || label(reminder.reminderType)}
                </AppText>
              ))
            ) : (
              <AppText>
                {overview.trackingStatus === 'ATTENTION'
                  ? 'Dikkat gerekiyor'
                  : overview.trackingStatus === 'DUE_SOON'
                    ? 'Yaklaşan işlem var'
                    : 'İyi'}
              </AppText>
            )}
          </View>
        </View>
      </Card>
    </Pressable>
  );
}
export function PrimaryCard({
  vehicle,
  onPress,
}: {
  vehicle: Vehicle;
  onPress: () => void;
}) {
  const { colors } = useTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel="Ana aracı seç"
      onPress={onPress}
    >
      <Card>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 16 }}>
          <View
            style={{
              width: 58,
              height: 58,
              borderRadius: 19,
              alignItems: 'center',
              justifyContent: 'center',
              backgroundColor: colors.primaryContainer,
            }}
          >
            <Icon name="car" size={29} color={colors.primary} />
          </View>
          <View style={{ flex: 1 }}>
            <AppText
              variant="titleMedium"
              numberOfLines={1}
              style={{ fontWeight: '900' }}
            >
              {vehicle.brand} {vehicle.model}
            </AppText>
            <View style={{ height: 8 }} />
            <Badge text="ANA ARAÇ" compact />
            <View style={{ height: 7 }} />
            <AppText style={{ fontWeight: '600' }}>
              {vehicle.plate} • {vehicle.modelYear}
            </AppText>
            <View style={{ height: 5 }} />
            <AppText variant="bodySmall">{number(vehicle.mileage)} km</AppText>
          </View>
          <Icon name="swap" color={colors.primary} />
        </View>
      </Card>
    </Pressable>
  );
}
export function LatestCard({
  inspection,
  onPress,
}: {
  inspection: Inspection;
  onPress: () => void;
}) {
  const { colors } = useTheme();
  const severity = inspection.damageSeverity ?? 'UNKNOWN';
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel="Son analizi aç"
      onPress={onPress}
    >
      <Card>
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <Badge
            text={
              severity === 'NONE'
                ? 'HASAR YOK'
                : severity === 'MINOR'
                  ? 'HAFİF'
                  : severity === 'MODERATE'
                    ? 'ORTA'
                    : severity === 'SEVERE'
                      ? 'AĞIR'
                      : 'BELİRSİZ'
            }
            status={severity}
            compact
          />
          <Icon name="outward" size={19} color={colors.secondaryText} />
        </View>
        <View style={{ height: 18 }} />
        <AppText variant="titleLarge" style={{ fontWeight: '900' }}>
          {severity === 'NONE'
            ? 'Görünür Hasar Tespit Edilmedi'
            : severity === 'MINOR'
              ? 'Hafif Seviye Hasar'
              : severity === 'MODERATE'
                ? 'Orta Seviye Hasar'
                : severity === 'SEVERE'
                  ? 'Ağır Seviye Hasar'
                  : 'Hasar Seviyesi Belirsiz'}
        </AppText>
        <View style={{ height: 7 }} />
        <AppText numberOfLines={2}>
          {inspection.affectedParts.length
            ? inspection.affectedParts.slice(0, 3).map(label).join(' • ')
            : 'Hasar analizi tamamlandı'}
        </AppText>
        <View style={{ height: 18 }} />
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
          <Icon name="carOutline" size={17} color={colors.secondaryText} />
          <AppText variant="bodySmall" style={{ flex: 1, fontWeight: '700' }}>
            {inspection.vehiclePlate}
          </AppText>
          <Icon name="calendar" size={15} color={colors.secondaryText} />
          <AppText variant="bodySmall">
            {inspection.completedAt || inspection.createdAt
              ? new Date(
                  (inspection.completedAt ?? inspection.createdAt)!,
                ).toLocaleDateString('tr-TR', {
                  day: 'numeric',
                  month: 'long',
                  year: 'numeric',
                })
              : '-'}
          </AppText>
        </View>
      </Card>
    </Pressable>
  );
}
