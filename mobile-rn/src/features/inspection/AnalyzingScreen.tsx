import { useEffect, useSyncExternalStore } from 'react';
import { ActivityIndicator, View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { positiveId } from '../../core/models';
import { AppText, Button, Icon } from '../../design/components';
import { Page, StateView } from '../../design/layout';
import { useTheme } from '../../design/ThemeProvider';
import { getAnalysis, type AnalysisJob } from './analysisJobs';
export default function AnalyzingScreen() {
  const router = useRouter(),
    { id: raw } = useLocalSearchParams<{ id: string }>(),
    id = positiveId(raw),
    job = getAnalysis(id);
  return job ? (
    <Running id={id} job={job} />
  ) : (
    <Page title="Analiz Durumu">
      <StateView empty="Analiz durumunu geçmiş kayıtlarından kontrol edin." />
      <Button
        label="Durumu Kontrol Et"
        onPress={() => router.replace(`/inspection/${id}`)}
      />
    </Page>
  );
}
function Running({ id, job }: { id: number; job: AnalysisJob }) {
  const router = useRouter(),
    snapshot = useSyncExternalStore(
      job.subscribe,
      job.getSnapshot,
      job.getSnapshot,
    ),
    { colors } = useTheme(),
    reduceMotion = useReducedMotion(),
    pulse = useSharedValue(1);
  useEffect(() => {
    if (!reduceMotion)
      pulse.value = withRepeat(withTiming(0.65, { duration: 1000 }), -1, true);
  }, [reduceMotion, pulse]);
  const animated = useAnimatedStyle(() => ({ opacity: pulse.value }));
  useEffect(() => {
    if (snapshot.phase === 'done') router.replace(`/inspection/${id}`);
  }, [snapshot.phase, id, router]);
  return (
    <Page title="Analiz Ediliyor">
      <View style={{ alignItems: 'center', paddingVertical: 50, gap: 24 }}>
        <Animated.View
          style={[
            {
              width: 112,
              height: 112,
              borderRadius: 36,
              alignItems: 'center',
              justifyContent: 'center',
              backgroundColor: colors.primaryContainer,
            },
            animated,
          ]}
        >
          <Icon name="sparkles" size={60} color={colors.primary} />
        </Animated.View>
        <AppText variant="headlineSmall">Aracınız değerlendiriliyor</AppText>
        {snapshot.phase === 'running' ? (
          <>
            <ActivityIndicator
              color={colors.primary}
              accessibilityLabel="Analiz sürüyor"
            />
            <AppText>
              Sunucu yanıtı bekleniyor. Fotoğraflar ve analiz sonucu kontrol
              ediliyor.
            </AppText>
          </>
        ) : (
          <StateView error={snapshot.error} />
        )}
        <AppText>
          Bu ekrandan ayrılırsanız işlem sunucuda devam edebilir. Yeniden analiz
          başlatmadan geçmiş kaydını kontrol edin.
        </AppText>
        <Button
          label="Analiz Durumunu Kontrol Et"
          variant="outlined"
          onPress={() => router.replace(`/inspection/${id}`)}
        />
      </View>
    </Page>
  );
}
