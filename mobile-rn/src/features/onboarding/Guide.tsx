import { useCallback, useEffect, useRef, useState } from 'react';
import {
  BackHandler,
  FlatList,
  ScrollView,
  useWindowDimensions,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { AppText, Button, Icon } from '../../design/components';
import { useTheme } from '../../design/ThemeProvider';
import { gradients } from '../../design/tokens';
import { steps } from './steps';
const art = {
  dark: [
    require('../../../assets/guide/welcome-dark.png'),
    require('../../../assets/guide/analysis-dark.png'),
    require('../../../assets/guide/reports-dark.png'),
    require('../../../assets/guide/garage-dark.png'),
    require('../../../assets/guide/assistant-dark.png'),
    require('../../../assets/guide/credits-dark.png'),
  ],
  light: [
    require('../../../assets/guide/welcome-light.png'),
    require('../../../assets/guide/analysis-light.png'),
    require('../../../assets/guide/reports-light.png'),
    require('../../../assets/guide/garage-light.png'),
    require('../../../assets/guide/assistant-light.png'),
    require('../../../assets/guide/credits-light.png'),
  ],
};
export default function Guide({
  onFinish,
  replay = false,
  saving = false,
}: {
  onFinish: () => void;
  replay?: boolean;
  saving?: boolean;
}) {
  const { colors, mode } = useTheme(),
    window = useWindowDimensions(),
    [width, setWidth] = useState(Math.min(window.width, 1040)),
    [index, setIndex] = useState(0),
    list = useRef<FlatList>(null),
    currentIndex = useRef(0);
  const go = useCallback(
    (next: number) => {
      currentIndex.current = next;
      setIndex(next);
      list.current?.scrollToOffset({ offset: next * width, animated: true });
    },
    [width],
  );
  useEffect(() => {
    const listener = BackHandler.addEventListener('hardwareBackPress', () => {
      if (saving) return true;
      if (index > 0) {
        go(index - 1);
        return true;
      }
      return false;
    });
    return () => listener.remove();
  }, [index, go, saving]);
  useEffect(() => {
    list.current?.scrollToOffset({
      offset: currentIndex.current * width,
      animated: false,
    });
  }, [width]);
  return (
    <SafeAreaView
      style={{ flex: 1, width: '100%', maxWidth: 1040, alignSelf: 'center' }}
      onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
    >
      <View
        style={{
          flexDirection: 'row',
          paddingLeft: 22,
          paddingRight: 12,
          paddingTop: 8,
          alignItems: 'center',
          gap: 10,
        }}
      >
        <LinearGradient
          colors={gradients.brand}
          style={{
            width: 32,
            height: 32,
            borderRadius: 11,
            justifyContent: 'center',
            alignItems: 'center',
          }}
        >
          <Icon name="sparkles" size={18} color="#fff" />
        </LinearGradient>
        <AppText variant="titleMedium" style={{ flex: 1, fontWeight: '800' }}>
          EksperSiz
        </AppText>
        <Button
          label={replay ? 'Kapat' : 'Atla'}
          variant="text"
          disabled={saving}
          onPress={onFinish}
        />
      </View>
      <FlatList
        ref={list}
        data={steps}
        horizontal
        pagingEnabled
        scrollEnabled={!saving}
        showsHorizontalScrollIndicator={false}
        keyExtractor={(item) => item.feature}
        getItemLayout={(_, item) => ({
          length: width,
          offset: width * item,
          index: item,
        })}
        onMomentumScrollEnd={(event) =>
          setIndex(
            Math.max(
              0,
              Math.min(
                steps.length - 1,
                Math.round(event.nativeEvent.contentOffset.x / width),
              ),
            ),
          )
        }
        renderItem={({ item, index: stepIndex }) => (
          <ScrollView
            style={{ width }}
            contentContainerStyle={{
              flexGrow: 1,
              paddingHorizontal: 22,
              paddingVertical: 20,
              justifyContent: 'center',
            }}
          >
            <View
              style={{
                flexDirection: width >= 700 ? 'row' : 'column',
                alignItems: width >= 700 ? 'center' : 'stretch',
                gap: width >= 700 ? 32 : 28,
              }}
            >
              <Image
                source={art[mode][stepIndex]}
                contentFit="contain"
                accessible={false}
                accessibilityElementsHidden
                style={{
                  width: width >= 700 ? '43%' : '100%',
                  maxWidth: 440,
                  aspectRatio: 1.2,
                  alignSelf: 'center',
                }}
              />
              <View style={{ flex: width >= 700 ? 1 : undefined, gap: 16 }}>
                <AppText
                  variant="bodySmall"
                  style={{
                    letterSpacing: 1.4,
                    color: colors.primary,
                    fontWeight: '800',
                  }}
                >
                  {item.category}
                </AppText>
                <AppText
                  variant="headlineLarge"
                  accessibilityRole="header"
                  style={{
                    fontSize: width < 360 ? 27 : 32,
                    lineHeight: width < 360 ? 30.51 : 36.16,
                    fontWeight: '800',
                    letterSpacing: -0.9,
                  }}
                >
                  {item.title}
                </AppText>
                <AppText
                  variant="bodyLarge"
                  style={{ lineHeight: 24.8, color: colors.secondaryText }}
                >
                  {item.description}
                </AppText>
                <View
                  style={{
                    padding: 13,
                    borderRadius: 14,
                    borderWidth: 1,
                    borderColor: colors.border,
                    backgroundColor: colors.low,
                    flexDirection: 'row',
                    gap: 10,
                  }}
                >
                  <Icon
                    name={item.feature === 'reports' ? 'warning' : 'chevron'}
                    color={colors.primary}
                    size={18}
                  />
                  <AppText
                    variant="bodySmall"
                    style={{
                      flex: 1,
                      fontSize: 13,
                      lineHeight: 19.5,
                      color: colors.text,
                    }}
                  >
                    {item.hint}
                  </AppText>
                </View>
              </View>
            </View>
          </ScrollView>
        )}
      />
      <View
        style={{
          width: '100%',
          maxWidth: 560,
          alignSelf: 'center',
          paddingHorizontal: 22,
          paddingTop: 8,
          paddingBottom: 16,
          gap: 16,
        }}
      >
        <View
          accessibilityLiveRegion="polite"
          accessibilityLabel={`Adım ${index + 1} / ${steps.length}: ${steps[index]?.category}`}
          style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}
        >
          <View style={{ flexDirection: 'row', flex: 1, gap: 6 }}>
            {steps.map((step, i) => (
              <View
                key={step.feature}
                style={{
                  flex: 1,
                  height: 4,
                  borderRadius: 4,
                  backgroundColor: i <= index ? colors.primary : colors.border,
                }}
              />
            ))}
          </View>
          <AppText variant="bodySmall">
            {index + 1} / {steps.length}
          </AppText>
        </View>
        <View style={{ flexDirection: 'row', gap: 14 }}>
          {index > 0 && (
            <Button
              label="Geri"
              variant="text"
              disabled={saving}
              onPress={() => go(index - 1)}
            />
          )}
          <View style={{ flex: 1 }}>
            <Button
              label={
                index === steps.length - 1
                  ? replay
                    ? 'Tamam'
                    : 'Başla'
                  : 'İleri'
              }
              loading={saving}
              icon={index === steps.length - 1 ? 'verified' : 'chevron'}
              onPress={() =>
                index === steps.length - 1 ? onFinish() : go(index + 1)
              }
            />
          </View>
        </View>
      </View>
    </SafeAreaView>
  );
}
