import { useState, useCallback } from 'react';
import {
  BackHandler,
  ScrollView,
  useWindowDimensions,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import Animated, { useReducedMotion } from 'react-native-reanimated';
import { AppText, Icon, type IconName } from '../../design/components';
import { TouchSurface } from '../../design/TouchSurface';
import { useTheme } from '../../design/ThemeProvider';
import { dimensions, motion, radius, spacing } from '../../design/tokens';
import { assistantClearance, FloatingAssistant } from './FloatingAssistant';
import HomeScreen from './HomeScreen';
import WorkspaceSwitcher from './WorkspaceSwitcher';
import VehicleListScreen from '../vehicle/VehicleListScreen';
import HistoryScreen from '../inspection/HistoryScreen';
import ProfileScreen from '../profile/ProfileScreen';

const destinations: [string, IconName, IconName][] = [
  ['Ana Sayfa', 'home', 'homeOutline'],
  ['Araçlar', 'car', 'carOutline'],
  ['Analizler', 'report', 'reportOutline'],
  ['Profil', 'person', 'person'],
];

export default function MainShell() {
  const { tab: initial } = useLocalSearchParams<{ tab?: string }>();
  const { colors, mode } = useTheme();
  const { width, height, fontScale } = useWindowDimensions();
  const reduce = useReducedMotion();
  const router = useRouter();
  const initialTab = Math.min(3, Math.max(0, Number(initial) || 0));
  const [tab, setTab] = useState(initialTab);
  const [visited, setVisited] = useState(new Set([initialTab]));
  const [assistantHeight, setAssistantHeight] = useState<number>(
    dimensions.fab,
  );
  const rail = width >= 900 || (width >= 600 && width > height);
  const select = (index: number) => {
    setTab(index);
    setVisited((current) =>
      current.has(index) ? current : new Set([...current, index]),
    );
  };
  useFocusEffect(
    useCallback(() => {
      const subscription = BackHandler.addEventListener(
        'hardwareBackPress',
        () => {
          if (tab === 0) return false;
          setTab(0);
          setVisited((current) =>
            current.has(0) ? current : new Set([...current, 0]),
          );
          return true;
        },
      );
      return () => subscription.remove();
    }, [tab]),
  );

  const item = (
    [title, filled, outline]: (typeof destinations)[number],
    index: number,
  ) => {
    const selected = tab === index;
    const color = selected
      ? mode === 'dark'
        ? colors.secondary
        : colors.primary
      : colors.secondaryText;
    return (
      <TouchSurface
        key={title}
        accessibilityRole="tab"
        accessibilityState={{ selected }}
        accessibilityLabel={title}
        onPress={() => select(index)}
        style={{
          flex: rail ? undefined : 1,
          minWidth: 0,
          minHeight: dimensions.touch,
          flexDirection: rail ? 'row' : 'column',
          paddingVertical: spacing.s,
          paddingHorizontal: rail ? spacing.xs : 0,
          alignItems: 'center',
          justifyContent: 'center',
          gap: spacing.xs,
          borderRadius: radius.medium,
        }}
      >
        <Animated.View
          style={{
            width: rail ? 40 : 56,
            flexShrink: 0,
            maxWidth: '100%',
            minHeight: spacing.xl,
            paddingVertical: spacing.xs,
            borderRadius: radius.pill,
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: selected ? colors.primaryContainer : 'transparent',
            transitionProperty: 'backgroundColor',
            transitionDuration: reduce ? 0 : motion.fast,
          }}
        >
          <Icon name={selected ? filled : outline} color={color} size={24} />
        </Animated.View>
        <AppText
          variant="bodySmall"
          style={{
            fontSize: rail ? 14 : 12,
            lineHeight: rail ? 20 : 18,
            fontWeight: selected ? '700' : '500',
            color,
            textAlign: rail ? 'left' : 'center',
            ...(rail ? { flex: 1 } : { alignSelf: 'stretch' }),
          }}
        >
          {title}
        </AppText>
      </TouchSurface>
    );
  };

  return (
    <SafeAreaView
      edges={['top', 'bottom', 'left', 'right']}
      style={{ flex: 1 }}
    >
      <WorkspaceSwitcher />
      <View
        style={{
          flex: 1,
          minHeight: 0,
          flexDirection: rail ? 'row' : 'column',
        }}
      >
        {rail && (
          <ScrollView
            style={{
              width: Math.min(200, 160 * Math.max(1, fontScale)),
              flexGrow: 0,
            }}
            contentContainerStyle={{ padding: spacing.s }}
          >
            <View
              accessibilityRole="tablist"
              style={{
                padding: spacing.s,
                borderRadius: radius.large,
                borderWidth: 1,
                borderColor: colors.border,
                backgroundColor: colors.surface,
                gap: spacing.s,
              }}
            >
              {destinations.map(item)}
            </View>
          </ScrollView>
        )}
        <View style={{ flex: 1, minWidth: 0, minHeight: 0 }}>
          <View testID="main-content" style={{ flex: 1, minHeight: 0 }}>
            {destinations.map(
              (_, index) =>
                visited.has(index) && (
                  <View
                    key={index}
                    style={{
                      flex: 1,
                      display: tab === index ? 'flex' : 'none',
                    }}
                    accessibilityElementsHidden={tab !== index}
                    importantForAccessibility={
                      tab === index ? 'auto' : 'no-hide-descendants'
                    }
                  >
                    {index === 0 ? (
                      <HomeScreen
                        contentBottom={assistantClearance(assistantHeight)}
                        onProfile={() => select(3)}
                        onVehicles={() => select(1)}
                        onHistory={() => select(2)}
                      />
                    ) : index === 1 ? (
                      <VehicleListScreen embedded />
                    ) : index === 2 ? (
                      <HistoryScreen embedded />
                    ) : (
                      <ProfileScreen embedded />
                    )}
                  </View>
                ),
            )}
          </View>
          {tab === 0 && (
            <FloatingAssistant
              onPress={() => router.push('/assistant')}
              onHeightChange={setAssistantHeight}
            />
          )}
        </View>
      </View>
      {!rail && (
        <View
          testID="bottom-navigation"
          accessibilityRole="tablist"
          style={{
            flexDirection: 'row',
            marginHorizontal: spacing.s,
            marginVertical: spacing.s,
            padding: spacing.xs,
            borderRadius: radius.large,
            borderWidth: 1,
            borderColor: colors.border,
            backgroundColor: colors.surface,
            minHeight: dimensions.navigation,
          }}
        >
          {destinations.map(item)}
        </View>
      )}
    </SafeAreaView>
  );
}
