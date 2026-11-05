import { View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import type { Inspection, Vehicle, VehicleOverview } from '../../core/models';
import { label, number } from '../../core/labels';
import { AppText, Card, Icon } from '../../design/components';
import { Badge } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import {
  dimensions,
  gradients,
  iconSize,
  radius,
  spacing,
} from '../../design/tokens';
import { TouchSurface } from '../../design/TouchSurface';
export function AnalysisHero({ onPress }: { onPress: () => void }) {
  return (
    <TouchSurface
      accessibilityRole="button"
      accessibilityLabel="Yeni Analiz Başlat"
      accessibilityHint="Fotoğraflarla AI hasar analizi oluşturun"
      onPress={onPress}
    >
      <LinearGradient
        colors={gradients.brand}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={{
          padding: spacing.ml,
          borderRadius: radius.large,
          gap: spacing.sm,
        }}
      >
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: spacing.sm,
          }}
        >
          <View
            style={{
              width: 40,
              height: 40,
              borderRadius: radius.small,
              backgroundColor: '#FFFFFF1F',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="sparkles" size={iconSize.default} color="#fff" />
          </View>
          <AppText
            variant="titleLarge"
            style={{ color: '#fff', flex: 1, minWidth: 0 }}
          >
            AI Hasar Analizi
          </AppText>
        </View>
        <AppText style={{ color: '#F3E8FF' }}>
          Hasarlı bölgenin fotoğrafını yükleyin, AI destekli raporunuzu
          oluşturun.
        </AppText>
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: spacing.s,
            borderTopWidth: 1,
            borderTopColor: '#FFFFFF33',
            paddingTop: spacing.sm,
          }}
        >
          <AppText
            variant="labelLarge"
            style={{ color: '#fff', flex: 1, minWidth: 0 }}
          >
            Yeni Analiz Başlat
          </AppText>
          <Icon name="forward" size={iconSize.medium} color="#fff" />
        </View>
      </LinearGradient>
    </TouchSurface>
  );
}
export function TrackingPeek({
  overview,
  onPress,
}: {
  overview: VehicleOverview;
  onPress: () => void;
}) {
  const { colors } = useTheme();
  const status = overview.trackingStatus;
  const attention = status === 'ATTENTION';
  const upcoming = status === 'DUE_SOON' || status === 'UPCOMING';
  const healthy = status === 'GOOD';
  const title = attention
    ? 'Dikkat gerekiyor'
    : upcoming
      ? 'Yaklaşan işlem var'
      : healthy
        ? 'Takibiniz güncel'
        : 'Takip durumu belirsiz';
  const color = attention
    ? colors.error
    : upcoming
      ? colors.warning
      : healthy
        ? colors.success
        : colors.secondaryText;
  const background = attention
    ? colors.errorSoft
    : upcoming
      ? colors.warningSoft
      : healthy
        ? colors.successSoft
        : colors.low;
  return (
    <TouchSurface
      accessibilityRole="button"
      accessibilityLabel={`Araç takibi, ${title}`}
      onPress={onPress}
    >
      <Card
        style={{
          borderRadius: radius.small,
          borderLeftWidth: 3,
          borderLeftColor: color,
        }}
      >
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'flex-start',
            gap: spacing.sm,
          }}
        >
          <View
            style={{
              width: 40,
              height: 40,
              borderRadius: radius.small,
              backgroundColor: background,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon
              name={attention ? 'warning' : upcoming ? 'clock' : 'health'}
              color={color}
              size={iconSize.medium}
            />
          </View>
          <View style={{ flex: 1, minWidth: 0, gap: spacing.xs }}>
            <AppText variant="bodySmall">Araç takibi</AppText>
            <AppText variant="titleSmall" style={{ color }}>
              {title}
            </AppText>
            {overview.upcomingReminders.slice(0, 2).map((reminder) => (
              <AppText key={reminder.id} variant="bodySmall">
                {reminder.title || label(reminder.reminderType)}
              </AppText>
            ))}
            {overview.upcomingReminders.length > 2 && (
              <AppText variant="bodySmall">
                +{overview.upcomingReminders.length - 2} hatırlatıcı daha
              </AppText>
            )}
          </View>
          <Icon
            name="chevron"
            color={colors.secondaryText}
            size={iconSize.medium}
          />
        </View>
      </Card>
    </TouchSurface>
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
    <TouchSurface
      accessibilityRole="button"
      accessibilityLabel="Ana aracı seç"
      onPress={onPress}
    >
      <Card>
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: spacing.sm,
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
            <Icon name="car" color={colors.onPrimaryContainer} />
          </View>
          <View style={{ flex: 1, minWidth: 0, gap: spacing.xs }}>
            <AppText variant="titleMedium">
              {vehicle.brand} {vehicle.model}
            </AppText>
            <Badge text="Ana araç" compact />
          </View>
          <Icon
            name="swap"
            color={colors.secondaryText}
            size={iconSize.medium}
          />
        </View>
        <View
          style={{
            flexDirection: 'row',
            flexWrap: 'wrap',
            gap: spacing.s,
            marginTop: spacing.m,
            paddingTop: spacing.sm,
            borderTopWidth: 1,
            borderTopColor: colors.border,
            alignItems: 'center',
          }}
        >
          <AppText variant="titleSmall" style={{ flexGrow: 1, flexShrink: 1 }}>
            {vehicle.plate}
          </AppText>
          <AppText variant="bodySmall">
            {vehicle.modelYear} · {number(vehicle.mileage)} km
          </AppText>
        </View>
      </Card>
    </TouchSurface>
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
    <TouchSurface
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
        <View style={{ height: spacing.m }} />
        <AppText variant="titleLarge" style={{ fontWeight: '700' }}>
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
        <View style={{ height: spacing.s }} />
        <AppText>
          {inspection.affectedParts.length
            ? inspection.affectedParts.slice(0, 3).map(label).join(' • ')
            : 'Hasar analizi tamamlandı'}
        </AppText>
        <View style={{ height: spacing.m }} />
        <View
          style={{
            flexDirection: 'row',
            flexWrap: 'wrap',
            alignItems: 'center',
            gap: 6,
          }}
        >
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
    </TouchSurface>
  );
}
