import { useCallback, useState } from 'react';
import { AppState, Pressable, View } from 'react-native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import { inspections } from '../../core/services';
import { useResource, invalidate } from '../../core/queries';
import { needsMorePhotos, positiveId } from '../../core/models';
import {
  AppText,
  Button,
  Card,
  Icon,
  IconButton,
} from '../../design/components';
import { InspectionPhoto } from '../../design/InspectionPhoto';
import { Page, StateView } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import { useAction } from '../auth/useAction';
import { reportContent, uniqueText } from './reportContent';
import { sharePdf } from './pdf';
import { damageAnalysisAvailable } from './CreateScreen';
export default function ResultScreen() {
  const { id: raw } = useLocalSearchParams<{ id: string }>(),
    id = positiveId(raw),
    router = useRouter(),
    { colors } = useTheme(),
    action = useAction(),
    [expanded, setExpanded] = useState(false),
    data = useResource(`inspection/${id}`, (signal) =>
      inspections.get(id, signal),
    ),
    inspection = data.data,
    content = inspection ? reportContent(inspection) : null,
    { refetch } = data;
  useFocusEffect(
    useCallback(() => {
      if (
        inspection?.status !== 'PROCESSING' &&
        inspection?.reportStatus !== 'PROCESSING'
      )
        return;
      const deadline = Date.now() + 180000,
        timer = setInterval(() => {
          if (Date.now() > deadline) clearInterval(timer);
          else if (AppState.currentState === 'active') void refetch();
        }, 5000);
      return () => clearInterval(timer);
    }, [inspection?.status, inspection?.reportStatus, refetch]),
  );
  const upload = () =>
      router.push({
        pathname: '/inspection/upload',
        params: { id: String(id) },
      }),
    completed = inspection?.status === 'COMPLETED',
    severity = inspection?.damageSeverity,
    color =
      inspection && needsMorePhotos(inspection)
        ? colors.secondaryText
        : severity === 'MINOR'
          ? colors.warning
          : severity === 'MODERATE'
            ? colors.moderate
            : severity === 'SEVERE'
              ? colors.error
              : severity === 'NONE'
                ? colors.success
                : colors.secondaryText;
  return (
    <Page
      title="Hasar Analiz Raporu"
      close
      themeToggle={false}
      contentTop={12}
      contentGap={12}
      contentMax={820}
      contentBottom={24}
      actions={
        completed && inspection?.report ? (
          <IconButton
            label={action.busy ? 'PDF hazırlanıyor' : 'PDF Raporunu Paylaş'}
            icon="pdfShare"
            disabled={action.busy}
            onPress={() => void action.run(() => sharePdf(inspection))}
          />
        ) : undefined
      }
      onRefresh={() => void data.refetch()}
      refreshing={data.isRefetching}
    >
      {!inspection || !content ? (
        <StateView
          loading={data.isPending}
          error={data.error}
          retry={() => void data.refetch()}
        />
      ) : (
        <>
          <Card>
            <AppText variant="titleSmall" style={{ fontWeight: '800' }}>
              {inspection.vehiclePlate} · {inspection.vehicleBrand}{' '}
              {inspection.vehicleModel}
            </AppText>
            <View style={{ height: 6 }} />
            <AppText variant="bodySmall">
              {inspection.locationCity} ·{' '}
              {inspection.completedAt || inspection.createdAt
                ? new Date(
                    (inspection.completedAt ?? inspection.createdAt)!,
                  ).toLocaleDateString('tr-TR')
                : '-'}
            </AppText>
            <View style={{ height: 18 }} />
            <View
              style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}
            >
              <Icon
                name={severity === 'NONE' ? 'shield' : 'crash'}
                color={color}
                size={26}
              />
              <AppText
                variant="titleLarge"
                style={{ flex: 1, color, fontWeight: '800' }}
              >
                {content.title}
              </AppText>
            </View>
            {uniqueText([inspection.analysisMessage]).map((note) => (
              <View key={note} style={{ paddingTop: 10 }}>
                <AppText style={{ lineHeight: 20.3 }}>{note}</AppText>
              </View>
            ))}
            {content.noDamage && (
              <View style={{ paddingTop: 10 }}>
                <AppText>İşlem Gerekmiyor</AppText>
              </View>
            )}
            <View
              style={{
                height: 1,
                marginVertical: 16,
                backgroundColor: colors.border,
              }}
            />
            <AppText
              variant="labelLarge"
              style={{ fontSize: 14, color: colors.secondaryText }}
            >
              {content.priceTitle}
            </AppText>
            <View style={{ height: 6 }} />
            <AppText variant="headlineSmall" style={{ fontWeight: '800' }}>
              {content.price}
            </AppText>
            {!!inspection.report?.priceInformation?.trim() && (
              <View style={{ paddingTop: 8 }}>
                <AppText variant="bodySmall" style={{ lineHeight: 16.8 }}>
                  {inspection.report.priceInformation}
                </AppText>
              </View>
            )}
          </Card>
          {!!content.findings.length && (
            <Card>
              <View
                style={{ flexDirection: 'row', gap: 8, alignItems: 'center' }}
              >
                <Icon name="findings" color={colors.secondaryText} size={20} />
                <AppText variant="titleMedium" style={{ fontWeight: '800' }}>
                  Bulgular ve Onarım
                </AppText>
              </View>
              <View style={{ height: 14 }} />
              {content.findings.map((finding, index) => (
                <View key={index}>
                  {index > 0 && (
                    <View
                      style={{
                        height: 1,
                        marginVertical: 14,
                        backgroundColor: colors.border,
                      }}
                    />
                  )}
                  <AppText variant="titleSmall" style={{ fontWeight: '800' }}>
                    {finding.part}
                  </AppText>
                  <View style={{ height: 4 }} />
                  <View
                    style={{
                      flexDirection: 'row',
                      flexWrap: 'wrap',
                      columnGap: 10,
                      rowGap: 4,
                    }}
                  >
                    {finding.damageTypes.map((type) => (
                      <AppText
                        key={type}
                        variant="labelLarge"
                        style={{ color: colors.primary, fontSize: 14 }}
                      >
                        {type}
                      </AppText>
                    ))}
                  </View>
                  {finding.observations.map((note, key) => (
                    <View key={key} style={{ paddingTop: 8 }}>
                      <AppText style={{ lineHeight: 19.6 }}>{note}</AppText>
                    </View>
                  ))}
                  {!!finding.repairs.length && (
                    <View
                      style={{
                        paddingTop: 10,
                        flexDirection: 'row',
                        alignItems: 'flex-start',
                        gap: 8,
                      }}
                    >
                      <Icon
                        name="build"
                        size={16}
                        color={colors.secondaryText}
                      />
                      <View style={{ flex: 1 }}>
                        {finding.repairs.map((repair, key) => (
                          <View key={key} style={{ paddingBottom: 4 }}>
                            <AppText style={{ lineHeight: 19.6 }}>
                              {repair}
                            </AppText>
                          </View>
                        ))}
                      </View>
                    </View>
                  )}
                </View>
              ))}
            </Card>
          )}
          <AppText variant="bodySmall" style={{ lineHeight: 16.8 }}>
            {content.disclaimer}
          </AppText>
          {needsMorePhotos(inspection) && (
            <Card>
              <AppText>
                {inspection.additionalPhotoGuidance ||
                  'Aynı hasarın genel görünümünü ve yakın planını yeniden çekin.'}
              </AppText>
              <View style={{ height: 12 }} />
              <Button
                label="Fotoğrafları Yenile"
                disabled={!damageAnalysisAvailable}
                icon="camera"
                onPress={upload}
              />
            </Card>
          )}
          {inspection.status === 'PROCESSING' && <StateView loading />}
          {['PENDING', 'FAILED'].includes(inspection.status) && (
            <Button
              label="Fotoğrafları Kontrol Et / Devam Et"
              disabled={!damageAnalysisAvailable}
              onPress={upload}
            />
          )}
          {(inspection.reportStatus === 'FAILED' ||
            inspection.reportMessage ||
            (completed && !inspection.report)) && (
            <Card>
              <AppText>
                {inspection.reportMessage || 'Detaylı rapor oluşturulamadı.'}
              </AppText>
              {completed &&
                inspection.reportStatus !== 'PROCESSING' &&
                (!inspection.report ||
                  inspection.reportStatus === 'FAILED') && (
                  <Button
                    label="AI Raporunu Yeniden Oluştur"
                    loading={action.busy}
                    onPress={() =>
                      void action.run(async () => {
                        await inspections.report(id);
                        await invalidate(`inspection/${id}`, 'inspections');
                      })
                    }
                  />
                )}
            </Card>
          )}
          {completed && (
            <>
              {!content.noDamage &&
                inspection.locationLatitude != null &&
                inspection.locationLongitude != null && (
                  <Button
                    label="Yakındaki Servisler"
                    icon="map"
                    variant="outlined"
                    onPress={() =>
                      router.push({
                        pathname: '/inspection/nearby',
                        params: { id: String(id) },
                      })
                    }
                  />
                )}
              <Button
                label="Tutanak Oluştur / Görüntüle"
                icon="report"
                variant="outlined"
                onPress={() =>
                  router.push({
                    pathname: '/inspection/record',
                    params: { id: String(id) },
                  })
                }
              />
            </>
          )}
          {!!inspection.imagePath && <InspectionPhoto id={id} />}
          <Card>
            <Pressable
              accessibilityRole="button"
              accessibilityState={{ expanded }}
              onPress={() => setExpanded((value) => !value)}
              style={{
                minHeight: 48,
                flexDirection: 'row',
                alignItems: 'center',
                gap: 8,
              }}
            >
              <Icon name="report" color={colors.secondaryText} />
              <AppText
                variant="titleMedium"
                style={{ flex: 1, fontWeight: '800' }}
              >
                Rapor Ayrıntıları
              </AppText>
              <Icon name="chevron" color={colors.secondaryText} />
            </Pressable>
            {expanded && (
              <View style={{ gap: 12, paddingTop: 12 }}>
                {content.narrative.map((text, index) => (
                  <AppText key={index}>{text}</AppText>
                ))}
                <AppText variant="bodySmall">
                  Güven skoru:{' '}
                  {inspection.confidenceScore == null
                    ? 'Belirtilmedi'
                    : `%${Math.round(inspection.confidenceScore * 100)}`}{' '}
                  · Şema: {inspection.schemaVersion ?? '-'} · Model:{' '}
                  {inspection.modelVersion ?? '-'}
                </AppText>
                {!!inspection.report?.priceSourceDescription && (
                  <AppText variant="bodySmall">
                    {inspection.report.priceSourceDescription}
                  </AppText>
                )}
              </View>
            )}
          </Card>
        </>
      )}
    </Page>
  );
}
