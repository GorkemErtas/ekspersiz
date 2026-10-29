import { memo } from 'react';
import { StyleSheet, useWindowDimensions, View } from 'react-native';
import Svg, {
  Defs,
  LinearGradient,
  Path,
  RadialGradient,
  Rect,
  Stop,
} from 'react-native-svg';
import { useTheme } from './ThemeProvider';

function luminance(hex: string) {
  const channels = [1, 3, 5].map((index) => {
    const value = parseInt(hex.slice(index, index + 2), 16) / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return channels[0]! * 0.2126 + channels[1]! * 0.7152 + channels[2]! * 0.0722;
}

/** Direct translation of _StudioSurfacePainter; anchored outside navigation/keyboard. */
export const StudioBackground = memo(function StudioBackground() {
  const { colors } = useTheme();
  const { width, height } = useWindowDimensions();
  const span = Math.min(width, 600),
    depth = Math.min(height, 1000);
  const strength = (dark: number, light: number) =>
    dark + (light - dark) * luminance(colors.background);
  return (
    <View
      pointerEvents="none"
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={StyleSheet.absoluteFill}
    >
      <Svg width={width} height={height}>
        <Defs>
          <RadialGradient
            id="upper"
            gradientUnits="userSpaceOnUse"
            cx={width - span * 0.08}
            cy={depth * 0.08}
            r={span * 1.12}
          >
            <Stop
              offset="0"
              stopColor={colors.primary}
              stopOpacity={strength(0.17, 0.065)}
            />
            <Stop
              offset="0.42"
              stopColor={colors.primary}
              stopOpacity={strength(0.17, 0.065) * 0.38}
            />
            <Stop offset="1" stopColor={colors.primary} stopOpacity={0} />
          </RadialGradient>
          <RadialGradient
            id="lower"
            gradientUnits="userSpaceOnUse"
            cx={-span * 0.22}
            cy={height - depth * 0.12}
            r={span * 1.25}
          >
            <Stop
              offset="0"
              stopColor={colors.secondary}
              stopOpacity={strength(0.085, 0.04)}
            />
            <Stop
              offset="0.42"
              stopColor={colors.secondary}
              stopOpacity={strength(0.085, 0.04) * 0.38}
            />
            <Stop offset="1" stopColor={colors.secondary} stopOpacity={0} />
          </RadialGradient>
          <LinearGradient
            id="edge"
            gradientUnits="userSpaceOnUse"
            x1="0"
            y1="0"
            x2={width}
            y2={height}
          >
            <Stop offset="0" stopColor={colors.secondary} stopOpacity={0} />
            <Stop
              offset="0.48"
              stopColor={colors.secondary}
              stopOpacity={strength(0.12, 0.095)}
            />
            <Stop offset="1" stopColor={colors.primary} stopOpacity={0} />
          </LinearGradient>
        </Defs>
        <Rect width={width} height={height} fill={colors.background} />
        <Rect width={width} height={height} fill="url(#upper)" />
        <Rect width={width} height={height} fill="url(#lower)" />
        <Path
          d={`M ${width - span * 0.62} ${-depth * 0.08} C ${width - span * 0.58} ${depth * 0.19}, ${width - span * 0.04} ${depth * 0.22}, ${width + span * 0.13} ${depth * 0.64}`}
          fill="none"
          stroke="url(#edge)"
          strokeWidth={1}
        />
        <Path
          d={`M ${-span * 0.17} ${height - depth * 0.64} C ${span * 0.05} ${height - depth * 0.31}, ${span * 0.34} ${height - depth * 0.27}, ${span * 0.46} ${height + depth * 0.08}`}
          fill="none"
          stroke="url(#edge)"
          strokeWidth={1}
        />
      </Svg>
    </View>
  );
});
