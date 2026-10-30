import { useState, useCallback } from 'react';
import {
  BackHandler,
  Pressable,
  useWindowDimensions,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import { AppText, Icon, type IconName } from '../../design/components';
import { useTheme } from '../../design/ThemeProvider';
import { LinearGradient } from 'expo-linear-gradient';
import { gradients, shadow } from '../../design/tokens';
import HomeScreen from './HomeScreen';
import WorkspaceSwitcher from './WorkspaceSwitcher';
import VehicleListScreen from '../vehicle/VehicleListScreen';
import HistoryScreen from '../inspection/HistoryScreen';
import ProfileScreen from '../profile/ProfileScreen';
const destinations: [string, IconName][] = [
  ['Ana Sayfa', 'home'],
  ['Araçlar', 'car'],
  ['Analizler', 'report'],
  ['Profil', 'person'],
];
const outlines: IconName[] = [
  'homeOutline',
  'carOutline',
  'reportOutline',
  'person',
];
export default function MainShell() {
  const { tab: initial } = useLocalSearchParams<{ tab?: string }>(),
    { colors, mode } = useTheme(),
    { width, fontScale } = useWindowDimensions(),
    router = useRouter();
  const initialTab = Math.min(3, Math.max(0, Number(initial) || 0));
  const [tab, setTab] = useState(initialTab),
    [visited, setVisited] = useState(new Set([initialTab]));
  const [railGroupHeight, setRailGroupHeight] = useState(0);
  const select = (index: number) => {
    setTab(index);
    setVisited((current) => new Set([...current, index]));
  };
  const rail = width >= 900 && fontScale <= 1.4;
  useFocusEffect(
    useCallback(() => {
      const subscription = BackHandler.addEventListener(
        'hardwareBackPress',
        () => {
          if (tab === 0) return false;
          setTab(0);
          setVisited((current) => new Set([...current, 0]));
          return true;
        },
      );
      return () => subscription.remove();
    }, [tab]),
  );
  const item = (index: number) => (
    <Pressable
      key={index}
      accessibilityRole="tab"
      accessibilityState={{ selected: tab === index }}
      accessibilityLabel={destinations[index]![0]}
      onPress={() => select(index)}
      style={({ pressed }) => ({
        flex: rail ? undefined : 1,
        minHeight: rail ? 64 : 58,
        paddingVertical: rail ? 4 : 3,
        paddingHorizontal: 4,
        alignItems: 'center',
        justifyContent: 'center',
        gap: 4,
        borderRadius: 18,
        opacity: pressed ? 0.7 : 1,
      })}
    >
      <View
        style={{
          width: rail ? 56 : 64,
          height: 32,
          borderRadius: 16,
          overflow: 'hidden',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor:
            tab === index ? colors.primaryContainer : 'transparent',
        }}
      >
        <Icon
          name={tab === index ? destinations[index]![1] : outlines[index]!}
          color={
            tab === index
              ? mode === 'dark'
                ? colors.secondary
                : colors.primary
              : colors.secondaryText
          }
          size={24}
        />
      </View>
      <AppText
        variant="bodySmall"
        numberOfLines={fontScale > 1.4 ? 2 : 1}
        style={{
          fontSize: rail ? 14 : 11,
          lineHeight: rail ? 20 : 15.95,
          fontWeight: '600',
          color:
            tab === index
              ? mode === 'dark'
                ? colors.secondary
                : colors.primary
              : colors.secondaryText,
        }}
      >
        {destinations[index]![0]}
      </AppText>
    </Pressable>
  );
  return (
    <SafeAreaView
      edges={['top', 'bottom', 'left', 'right']}
      style={{ flex: 1 }}
    >
      <WorkspaceSwitcher />
      <View style={{ flex: 1, flexDirection: rail ? 'row' : 'column' }}>
        {rail && (
          <View
            accessibilityRole="tablist"
            style={{
              width: 113,
            }}
          >
            <View
              style={{
                flex: 1,
                margin: 14,
                borderRadius: 24,
                borderWidth: 1,
                borderColor: '#8B5CF629',
                backgroundColor: colors.surface,
                boxShadow: shadow(mode, 'elevated'),
              }}
            >
              <View
                style={{
                  alignItems: 'center',
                  paddingTop: 26,
                  paddingBottom: 30,
                }}
              >
                <LinearGradient
                  colors={gradients.brand}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={{
                    width: 54,
                    height: 54,
                    borderRadius: 18,
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: shadow(mode, 'primary'),
                  }}
                >
                  <Icon name="crashRound" size={28} color="#fff" />
                </LinearGradient>
              </View>
              <View
                onLayout={(event) =>
                  setRailGroupHeight(event.nativeEvent.layout.height)
                }
                style={{ flex: 1 }}
              >
                <View
                  style={{
                    paddingTop: Math.max(0, (railGroupHeight - 256) * 0.14),
                  }}
                >
                  {destinations.map((_, index) => item(index))}
                </View>
              </View>
            </View>
          </View>
        )}
        <View style={{ flex: 1 }}>
          {destinations.map(
            (_, index) =>
              visited.has(index) && (
                <View
                  key={index}
                  style={{ flex: 1, display: tab === index ? 'flex' : 'none' }}
                  accessibilityElementsHidden={tab !== index}
                  importantForAccessibility={
                    tab === index ? 'auto' : 'no-hide-descendants'
                  }
                >
                  {index === 0 ? (
                    <HomeScreen
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
      </View>
      {tab === 0 && (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="AI Asistan’ı aç"
          onPress={() => router.push('/assistant')}
          style={{
            position: 'absolute',
            right: 16,
            bottom: rail ? 128 : 98,
            width: 52,
            height: 52,
            borderRadius: 26,
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: colors.primary,
            boxShadow: '0 5px 22px #6D28D94D',
          }}
        >
          <LinearGradient
            colors={gradients.deep}
            style={{
              width: 52,
              height: 52,
              borderRadius: 26,
              borderWidth: 1,
              borderColor: '#FFFFFF29',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="sparkles" color="#FFFFFF" size={24} />
          </LinearGradient>
        </Pressable>
      )}
      {!rail && (
        <View
          accessibilityRole="tablist"
          style={{
            flexDirection: 'row',
            marginHorizontal: 12,
            marginTop: 6,
            marginBottom: 0,
            padding: 6,
            borderRadius: 24,
            borderWidth: 1,
            borderColor: colors.border,
            backgroundColor: colors.surface,
            minHeight: 72,
          }}
        >
          {destinations.map((_, index) => item(index))}
        </View>
      )}
    </SafeAreaView>
  );
}
