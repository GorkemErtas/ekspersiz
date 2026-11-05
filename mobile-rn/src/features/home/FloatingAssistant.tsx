import { View } from 'react-native';
import { AppText, Icon } from '../../design/components';
import { TouchSurface } from '../../design/TouchSurface';
import { useTheme } from '../../design/ThemeProvider';
import {
  borders,
  dimensions,
  iconSize,
  radius,
  shadow,
  spacing,
} from '../../design/tokens';

export const assistantClearance = (height: number) => height + spacing.sm * 2;

export function FloatingAssistant({
  onPress,
  onHeightChange,
}: {
  onPress: () => void;
  onHeightChange: (height: number) => void;
}) {
  const { colors, mode } = useTheme();
  return (
    <View
      testID="assistant-overlay"
      pointerEvents="box-none"
      style={{
        position: 'absolute',
        bottom: spacing.sm,
        left: spacing.page,
        right: spacing.page,
        alignItems: 'flex-end',
        backgroundColor: 'transparent',
      }}
    >
      <TouchSurface
        onLayout={(event) =>
          onHeightChange(Math.ceil(event.nativeEvent.layout.height))
        }
        accessibilityRole="button"
        accessibilityLabel="AI Asistan’ı aç"
        onPress={onPress}
        style={{
          minHeight: dimensions.fab,
          maxWidth: '100%',
          paddingVertical: spacing.sm,
          paddingHorizontal: spacing.m,
          borderRadius: radius.pill,
          borderWidth: borders.hairline,
          borderColor: mode === 'dark' ? colors.outline : colors.border,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          gap: spacing.s,
          backgroundColor: colors.primaryContainer,
          boxShadow: shadow(mode, 'primary'),
        }}
      >
        <Icon
          name="sparkles"
          color={colors.onPrimaryContainer}
          size={iconSize.medium}
        />
        <AppText
          variant="labelLarge"
          style={{ color: colors.onPrimaryContainer, flexShrink: 1 }}
        >
          AI Asistan
        </AppText>
      </TouchSurface>
    </View>
  );
}
