import type { TextStyle } from 'react-native';

// EksperSiz brand identity. All dimensions are logical pixels on a 4-point scale.
export const brand = {
  primary: '#8B5CF6',
  primaryDark: '#6D28D9',
  secondary: '#C084FC',
  accent: '#A78BFA',
} as const;
export const spacing = {
  xs: 4,
  s: 8,
  sm: 12,
  m: 16,
  ml: 20,
  l: 24,
  xl: 32,
  xxl: 40,
  page: 16,
  card: 16,
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
  button: 52,
  input: 52,
  content: 1100,
  auth: 460,
  authWide: 520,
  toolbar: 60,
  fab: 48,
  navigation: 72,
} as const;
export const iconSize = {
  small: 16,
  medium: 20,
  default: 24,
  large: 32,
} as const;
export const borders = { hairline: 1, focus: 2 } as const;
export const motion = {
  fast: 160,
  medium: 220,
  slow: 280,
  theme: 240,
  pressedScale: 0.985,
} as const;
export const gradients = {
  brand: ['#4C1D95', '#6D28D9', '#7C3AED'],
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
    muted: '#A198AD',
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
    muted: '#71657C',
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
  // Use the bundled faces; avoid introducing a network font dependency.
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
    lineHeight: 60,
    letterSpacing: -1.6,
    fontFamily: fonts.regular,
    fontWeight: '900',
  },
  displayMedium: {
    fontSize: 42,
    lineHeight: 48,
    letterSpacing: -1.2,
    fontFamily: fonts.regular,
    fontWeight: '900',
  },
  headlineLarge: {
    fontSize: 30,
    lineHeight: 40,
    letterSpacing: -0.9,
    fontFamily: fonts.regular,
    fontWeight: '900',
  },
  headlineMedium: {
    fontSize: 26,
    lineHeight: 36,
    letterSpacing: -0.7,
    fontFamily: fonts.regular,
    fontWeight: '900',
  },
  headlineSmall: {
    fontSize: 22,
    lineHeight: 32,
    letterSpacing: -0.45,
    fontFamily: fonts.regular,
    fontWeight: '800',
  },
  titleLarge: {
    fontSize: 20,
    lineHeight: 28,
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
    letterSpacing: 0.2,
    fontFamily: fonts.regular,
  },
  bodyMedium: {
    fontSize: 14,
    lineHeight: 20,
    letterSpacing: 0.15,
    fontFamily: fonts.regular,
  },
  bodySmall: {
    fontSize: 12,
    lineHeight: 18,
    letterSpacing: 0.2,
    fontFamily: fonts.regular,
  },
  labelLarge: {
    fontSize: 15,
    lineHeight: 24,
    letterSpacing: -0.1,
    fontFamily: fonts.medium,
    fontWeight: '700',
  },
} satisfies Record<string, TextStyle>;

export function shadow(mode: ThemeMode, kind: 'soft' | 'elevated' | 'primary') {
  const dark = mode === 'dark';
  return {
    soft: [
      {
        offsetX: 0,
        offsetY: 2,
        blurRadius: 8,
        color: dark ? '#00000029' : '#3D284D0F',
      },
    ],
    elevated: [
      {
        offsetX: 0,
        offsetY: 6,
        blurRadius: 20,
        color: dark ? '#00000047' : '#3D284D1A',
      },
    ],
    primary: [
      {
        offsetX: 0,
        offsetY: 4,
        blurRadius: 12,
        color: dark ? '#0000003D' : '#4C1D9524',
      },
    ],
  }[kind];
}
