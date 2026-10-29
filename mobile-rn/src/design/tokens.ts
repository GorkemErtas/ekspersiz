import type { TextStyle } from 'react-native';

// Source: mobile/lib/core/theme/app_theme.dart. Values are logical pixels.
export const brand = {
  primary: '#8B5CF6',
  primaryDark: '#6D28D9',
  secondary: '#C084FC',
  accent: '#A78BFA',
} as const;
export const spacing = {
  xs: 4,
  s: 8,
  m: 15,
  l: 22,
  xl: 30,
  xxl: 36,
  page: 18,
  card: 18,
} as const;
export const radius = {
  small: 12,
  medium: 16,
  large: 24,
  xlarge: 28,
  pill: 999,
} as const;
export const dimensions = {
  touch: 48,
  button: 50,
  content: 1100,
  auth: 460,
  authWide: 520,
  toolbar: 60,
} as const;
export const motion = {
  fast: 140,
  medium: 240,
  slow: 320,
  theme: 420,
  pressedScale: 0.985,
} as const;
export const gradients = {
  brand: ['#6D28D9', '#8B5CF6', '#C084FC'],
  deep: ['#171021', '#291448', '#6D28D9'],
} as const;
export const palettes = {
  dark: {
    background: '#08070B',
    surface: '#111014',
    low: '#0E0D11',
    container: '#151319',
    high: '#1B1820',
    highest: '#24202B',
    text: '#F7F4FB',
    secondaryText: '#B9B1C5',
    muted: '#81798D',
    outline: '#746880',
    border: '#2A2631',
    primary: brand.primary,
    onPrimary: '#110818',
    primaryContainer: '#2B1A46',
    onPrimaryContainer: '#E9D5FF',
    secondary: brand.secondary,
    secondaryContainer: '#291A35',
    onSecondaryContainer: '#F3E8FF',
    input: '#0E0D11',
    inputIcon: '#9F8FB2',
    error: '#FB7185',
    errorSoft: '#35151B',
    success: '#34D399',
    successSoft: '#102A22',
    warning: '#FBBF24',
    warningSoft: '#30240B',
    moderate: '#FB923C',
    moderateSoft: '#33200F',
    info: '#A78BFA',
    infoSoft: '#241B36',
  },
  light: {
    background: '#F8F6FB',
    surface: '#FFFFFF',
    low: '#F4F0F8',
    container: '#F0EBF5',
    high: '#EAE3F0',
    highest: '#E2D9E9',
    text: '#211A29',
    secondaryText: '#655C6F',
    muted: '#81778B',
    outline: '#7B7185',
    border: '#D9D0E1',
    primary: brand.primaryDark,
    onPrimary: '#FFFFFF',
    primaryContainer: '#EBDDFF',
    onPrimaryContainer: '#32105A',
    secondary: '#7C3AED',
    secondaryContainer: '#F0E4FF',
    onSecondaryContainer: '#32104F',
    input: '#FCFAFD',
    inputIcon: '#766685',
    error: '#BA1A1A',
    errorSoft: '#FFE1E6',
    success: '#087A55',
    successSoft: '#DDF8EC',
    warning: '#8A5A00',
    warningSoft: '#FFF1C7',
    moderate: '#B54708',
    moderateSoft: '#FFE8D2',
    info: '#6D28D9',
    infoSoft: '#F0E7FF',
  },
} as const;
export type ThemeMode = keyof typeof palettes;
export type Palette = { [K in keyof typeof palettes.dark]: string };

export const fonts = {
  // GoogleFonts.interTextTheme chooses regular/medium families first; Flutter's
  // copyWith(weight) retains that family. Match that behavior and original bytes.
  regular: 'InterRegular',
  medium: 'InterMedium',
  semibold: 'InterRegular',
  bold: 'InterMedium',
  extraBold: 'InterRegular',
  black: 'InterRegular',
} as const;
export const typography = {
  displayLarge: {
    fontSize: 54,
    lineHeight: 56.16,
    letterSpacing: -1.6,
    fontFamily: fonts.regular,
    fontWeight: '900',
  },
  displayMedium: {
    fontSize: 42,
    lineHeight: 44.52,
    letterSpacing: -1.2,
    fontFamily: fonts.regular,
    fontWeight: '900',
  },
  headlineLarge: {
    fontSize: 30,
    lineHeight: 37.5,
    letterSpacing: -0.9,
    fontFamily: fonts.regular,
    fontWeight: '900',
  },
  headlineMedium: {
    fontSize: 26,
    lineHeight: 33.4286,
    letterSpacing: -0.7,
    fontFamily: fonts.regular,
    fontWeight: '900',
  },
  headlineSmall: {
    fontSize: 22,
    lineHeight: 29.3333,
    letterSpacing: -0.45,
    fontFamily: fonts.regular,
    fontWeight: '800',
  },
  titleLarge: {
    fontSize: 20,
    lineHeight: 25.4545,
    letterSpacing: -0.3,
    fontFamily: fonts.regular,
    fontWeight: '800',
  },
  titleMedium: {
    fontSize: 16,
    lineHeight: 24,
    letterSpacing: 0.15,
    fontFamily: fonts.medium,
    fontWeight: '700',
  },
  titleSmall: {
    fontSize: 14,
    lineHeight: 20,
    fontFamily: fonts.medium,
    fontWeight: '700',
  },
  bodyLarge: {
    fontSize: 16,
    lineHeight: 24,
    letterSpacing: 0.5,
    fontFamily: fonts.regular,
  },
  bodyMedium: {
    fontSize: 14,
    lineHeight: 21,
    letterSpacing: 0.25,
    fontFamily: fonts.regular,
  },
  bodySmall: {
    fontSize: 12,
    lineHeight: 17.4,
    letterSpacing: 0.4,
    fontFamily: fonts.regular,
  },
  labelLarge: {
    fontSize: 15,
    lineHeight: 21.4286,
    letterSpacing: -0.1,
    fontFamily: fonts.medium,
    fontWeight: '700',
  },
} satisfies Record<string, TextStyle>;

export function shadow(mode: ThemeMode, kind: 'soft' | 'elevated' | 'primary') {
  // Flutter blur radius -> sigma: radius * .57735 + .5; RN uses CSS blur diameter.
  if (mode === 'light')
    return {
      soft: [
        {
          offsetX: 0,
          offsetY: 10,
          blurRadius: 28.71,
          color: 'rgba(61,40,77,0.08)',
        },
      ],
      elevated: [
        {
          offsetX: 0,
          offsetY: 15,
          blurRadius: 40.26,
          color: 'rgba(61,40,77,0.13)',
        },
      ],
      primary: [
        {
          offsetX: 0,
          offsetY: 12,
          blurRadius: 33.33,
          color: 'rgba(109,40,217,0.18)',
        },
      ],
    }[kind];
  return {
    soft: [
      { offsetX: 0, offsetY: 12, blurRadius: 33.33, color: 'rgba(0,0,0,0.34)' },
      {
        offsetX: 0,
        offsetY: 6,
        blurRadius: 28.71,
        color: 'rgba(139,92,246,0.045)',
      },
    ],
    elevated: [
      { offsetX: 0, offsetY: 18, blurRadius: 49.5, color: 'rgba(0,0,0,0.48)' },
      {
        offsetX: 0,
        offsetY: 12,
        blurRadius: 40.26,
        color: 'rgba(139,92,246,0.08)',
      },
    ],
    primary: [
      {
        offsetX: 0,
        offsetY: 14,
        blurRadius: 40.26,
        color: 'rgba(139,92,246,0.28)',
      },
    ],
  }[kind];
}
