import { spacing } from '../../design/tokens';
import { TouchSurface } from '../../design/TouchSurface';
import { FlatList, View } from 'react-native';
import { useRouter } from 'expo-router';
import { inspections } from '../../core/services';
import { useSession } from '../../core/runtime';
import { useResource } from '../../core/queries';
import { label } from '../../core/labels';
import { AppText, Card, Icon } from '../../design/components';
import { Badge, layoutStyles, Page, StateView } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
export default function HistoryScreen({
  embedded = false,
}: {
  embedded?: boolean;
}) {
  const router = useRouter(),
    data = useResource('inspections', inspections.list),
    { profile, workspace } = useSession(),
    { colors } = useTheme(),
    items = data.data
      ?.filter((item) => item.status === 'COMPLETED')
      .sort((a, b) =>
        String(b.completedAt ?? b.createdAt).localeCompare(
          String(a.completedAt ?? a.createdAt),
        ),
      );
  return (
    <Page
      title="Analiz Geçmişi"
      embedded={embedded}
      back={!embedded}
      scroll={false}
    >
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
          data={items}
          keyExtractor={(item) => String(item.id)}
          contentContainerStyle={layoutStyles.listContent}
          refreshing={data.isRefetching}
          onRefresh={() => void data.refetch()}
          ListHeaderComponent={
            items?.length ? (
              <View style={{ marginBottom: 4 }}>
                <AppText variant="headlineSmall" style={{ fontWeight: '900' }}>
                  {workspace === 'BUSINESS'
                    ? `${profile?.businessAccount?.companyName} analizleri`
                    : 'Analiz geçmişiniz'}
                </AppText>
                <View style={{ height: 7 }} />
                <AppText
                  variant="bodyLarge"
                  style={{ color: colors.secondaryText, lineHeight: 23.2 }}
                >
                  {workspace === 'BUSINESS'
                    ? 'Tüm şirket üyelerinin tamamladığı ortak analizleri ve AI raporlarını inceleyin. Analizler ortak kredi bakiyesinden kullanılır.'
                    : 'Tamamlanan araç hasar analizlerinizi ve AI raporlarınızı inceleyin.'}
                </AppText>
                <View style={{ height: 18 }} />
                <View
                  style={{
                    alignSelf: 'flex-start',
                    maxWidth: '100%',
                    paddingHorizontal: 12,
                    paddingVertical: 7,
                    borderRadius: 99,
                    backgroundColor: colors.primaryContainer,
                    flexDirection: 'row',
                    gap: 6,
                    alignItems: 'center',
                  }}
                >
                  <Icon name="history" size={14} color={colors.primary} />
                  <AppText
                    variant="bodySmall"
                    style={{
                      color: colors.primary,
                      fontWeight: '700',
                      flexShrink: 1,
                    }}
                  >
                    {items.length} tamamlanan analiz
                  </AppText>
                </View>
              </View>
            ) : undefined
          }
          ListEmptyComponent={
            <StateView empty="Henüz tamamlanan analiz yok. AI destekli bir hasar analizi tamamladığınızda raporunuz burada görüntülenecek." />
          }
          renderItem={({ item }) => {
            const severity = item.damageSeverity,
              color =
                severity === 'MINOR'
                  ? colors.warning
                  : severity === 'MODERATE'
                    ? colors.moderate
                    : severity === 'SEVERE'
                      ? colors.error
                      : severity === 'NONE'
                        ? colors.success
                        : colors.secondaryText,
              soft =
                severity === 'MINOR'
                  ? colors.warningSoft
                  : severity === 'MODERATE'
                    ? colors.moderateSoft
                    : severity === 'SEVERE'
                      ? colors.errorSoft
                      : severity === 'NONE'
                        ? colors.successSoft
                        : colors.low,
              date = item.completedAt ?? item.createdAt;
            return (
              <TouchSurface
                accessibilityRole="button"
                accessibilityLabel={`${item.vehiclePlate} analiz raporu`}
                onPress={() => router.push(`/inspection/${item.id}`)}
              >
                <Card>
                  <View
                    style={{
                      flexDirection: 'row',
                      alignItems: 'flex-start',
                      gap: spacing.sm,
                    }}
                  >
                    <View
                      style={{
                        width: 54,
                        height: 54,
                        borderRadius: 18,
                        backgroundColor: soft,
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Icon
                        name={
                          severity === 'NONE'
                            ? 'shield'
                            : severity
                              ? 'crash'
                              : 'report'
                        }
                        color={color}
                        size={27}
                      />
                    </View>
                    <View style={{ flex: 1, minWidth: 0 }}>
                      <AppText
                        variant="titleMedium"
                        style={{ fontWeight: '900' }}
                      >
                        {item.vehiclePlate}
                      </AppText>
                      <View style={{ height: 5 }} />
                      <View
                        style={{
                          flexDirection: 'row',
                          alignItems: 'center',
                          gap: 4,
                        }}
                      >
                        <Icon
                          name="location"
                          color={colors.secondaryText}
                          size={15}
                        />
                        <AppText
                          variant="bodySmall"
                          style={{ fontWeight: '600', flexShrink: 1 }}
                        >
                          {item.locationCity}
                        </AppText>
                      </View>
                    </View>
                    <Icon name="chevron" color={colors.secondaryText} />
                  </View>
                  <View style={{ height: spacing.m }} />
                  <View
                    style={{
                      flexDirection: 'row',
                      flexWrap: 'wrap',
                      gap: 12,
                      alignItems: 'center',
                    }}
                  >
                    <Badge
                      text={
                        severity === 'NONE'
                          ? 'Görünür Hasar Yok'
                          : severity === 'MINOR'
                            ? 'Hafif Hasar'
                            : severity === 'MODERATE'
                              ? 'Orta Hasar'
                              : severity === 'SEVERE'
                                ? 'Ağır Hasar'
                                : 'Hasar Seviyesi Belirsiz'
                      }
                      status={severity ?? ''}
                    />
                    <View
                      style={{
                        flexDirection: 'row',
                        alignItems: 'center',
                        gap: 5,
                      }}
                    >
                      <Icon
                        name="calendar"
                        size={15}
                        color={colors.secondaryText}
                      />
                      <AppText
                        variant="bodySmall"
                        style={{ fontWeight: '600', flexShrink: 1 }}
                      >
                        {date
                          ? new Date(date).toLocaleDateString('tr-TR')
                          : '-'}
                      </AppText>
                    </View>
                  </View>
                  {!!item.affectedParts?.length && (
                    <>
                      <View
                        style={{
                          height: 1,
                          marginTop: 15,
                          marginBottom: 14,
                          backgroundColor: colors.border,
                        }}
                      />
                      <View
                        style={{
                          flexDirection: 'row',
                          alignItems: 'flex-start',
                          gap: 8,
                        }}
                      >
                        <Icon name="build" size={17} color={colors.primary} />
                        <AppText
                          variant="bodySmall"
                          numberOfLines={2}
                          style={{
                            flex: 1,
                            lineHeight: 16.8,
                            fontWeight: '600',
                          }}
                        >
                          {item.affectedParts.map(label).join(' • ')}
                        </AppText>
                      </View>
                    </>
                  )}
                </Card>
              </TouchSurface>
            );
          }}
        />
      )}
    </Page>
  );
}
