import { useState, type ReactNode, type Ref } from 'react';
import {
  ActivityIndicator,
  Image,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  TextInput,
  useWindowDimensions,
  View,
  type TextInputInstance,
  type TextInputProps,
  type TextProps,
  type ViewStyle,
} from 'react-native';
import {
  SafeAreaView,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import Animated, {
  Easing,
  FadeIn,
  ReduceMotion,
  useReducedMotion,
} from 'react-native-reanimated';
import { useTheme } from './ThemeProvider';
import { TouchSurface } from './TouchSurface';
import {
  dimensions,
  borders,
  fonts,
  iconSize,
  motion,
  radius,
  shadow,
  spacing,
  typography,
} from './tokens';

const glyphs = {
  outward: 0xf0019,
  crashRound: 0xf07eb,
  pdfShare: 0xf826,
  search: 0xf013d,
  build: 0xef06,
  location: 0xf193,
  history: 0xf7ef,
  more: 0xf8dc,
  badge: 0xeeb8,
  garage: 0xf0bf,
  star: 0xf01d4,
  speed: 0xf01b5,
  crash: 0xf06e3,
  findings: 0xf89f,
  close: 0xf647,
  premium: 0xf06a1,
  forward: 0xf57a,
  swap: 0xf01fa,
  health: 0xf0f2,
  carOutline: 0xefc6,
  homeOutline: 0xf107,
  reportOutline: 0xefae,
  home: 0xf7f5,
  car: 0xf6b3,
  report: 0xf69b,
  bell: 0xf237,
  sparkles: 0xf596,
  shield: 0xf379,
  chevron: 0xf63b,
  calendar: 0xf051f,
  warning: 0xf02a0,
  tools: 0xef06,
  add: 0xf537,
  edit: 0xf00d,
  camera: 0xf29b,
  gallery: 0xf29d,
  map: 0xf1ae,
  mic: 0xf8bd,
  stop: 0xf01dc,
  share: 0xf378,
  email: 0xf89b,
  lock: 0xf888,
  visible: 0xf4a1,
  hidden: 0xf4a0,
  login: 0xf88a,
  google: 0xf7a8,
  personAdd: 0xf0067,
  person: 0xf006c,
  back: 0xf572,
  verifiedEmail: 0xf1b5,
  password: 0xf0050,
  clock: 0xf012b,
  verified: 0xf026e,
  refresh: 0xf00e9,
  reset: 0xf034d,
  send: 0xf0147,
  dark: 0xf68c,
  light: 0xf852,
  logout: 0xf88b,
  business: 0xf5f8,
  delete: 0xf696,
} as const;
export type IconName = keyof typeof glyphs;
export function IconButton({
  label,
  icon,
  onPress,
  disabled = false,
  surface = false,
  filled = false,
  color,
}: {
  label: string;
  icon: IconName;
  onPress: () => void;
  disabled?: boolean;
  surface?: boolean;
  filled?: boolean;
  color?: string;
}) {
  const { colors } = useTheme();
  return (
    <TouchSurface
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={{
        width: dimensions.touch,
        height: dimensions.touch,
        borderRadius: radius.small,
        backgroundColor: filled
          ? colors.primary
          : surface
            ? colors.surface
            : 'transparent',
        borderWidth: surface ? borders.hairline : 0,
        borderColor: colors.border,
        alignItems: 'center',
        justifyContent: 'center',
        opacity: disabled ? 0.5 : 1,
      }}
    >
      <Icon
        name={icon}
        color={color ?? (filled ? colors.onPrimary : colors.text)}
      />
    </TouchSurface>
  );
}
export function Icon({
  name,
  size = iconSize.default,
  color,
}: {
  name: IconName;
  size?: number;
  color?: string;
}) {
  const { colors } = useTheme();
  const reduce = useReducedMotion();
  return (
    <Animated.Text
      accessible={false}
      importantForAccessibility="no"
      allowFontScaling={false}
      style={{
        fontFamily: 'FlutterMaterialIcons',
        fontSize: size,
        lineHeight: size,
        width: size,
        height: size,
        textAlign: 'center',
        color: color ?? colors.text,
        includeFontPadding: false,
        transitionProperty: 'color',
        transitionDuration: reduce ? 0 : motion.theme,
      }}
    >
      {String.fromCodePoint(glyphs[name])}
    </Animated.Text>
  );
}
export function AppText({
  variant = 'bodyMedium',
  style,
  ...props
}: TextProps & { variant?: keyof typeof typography }) {
  const { colors } = useTheme();
  const reduce = useReducedMotion();
  return (
    <Animated.Text
      {...props}
      style={[
        typography[variant],
        {
          color:
            variant.startsWith('body') && variant !== 'bodyLarge'
              ? colors.secondaryText
              : colors.text,
          includeFontPadding: false,
          transitionProperty: 'color',
          transitionDuration: reduce ? 0 : motion.theme,
        },
        style,
      ]}
    />
  );
}
export function Gap({ size = spacing.m }: { size?: number }) {
  return <View style={{ height: size }} />;
}

export function Button({
  label,
  onPress,
  loading = false,
  disabled = false,
  icon,
  variant = 'primary',
}: {
  label: string;
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
  icon?: IconName;
  variant?: 'primary' | 'outlined' | 'text' | 'danger';
}) {
  const { colors, mode } = useTheme();
  const [focused, setFocused] = useState(false);
  const blocked = disabled || loading;
  const text = blocked
    ? colors.secondaryText
    : variant === 'primary'
      ? colors.onPrimary
      : variant === 'danger'
        ? colors.error
        : variant === 'text'
          ? mode === 'dark'
            ? colors.secondary
            : colors.primary
          : colors.text;
  return (
    <TouchSurface
      onPress={onPress}
      disabled={blocked}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: blocked, busy: loading }}
      accessibilityLiveRegion={loading ? 'polite' : 'none'}
      android_ripple={{ color: mode === 'dark' ? '#FFFFFF1F' : '#00000014' }}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      style={[
        {
          minHeight: variant === 'text' ? dimensions.touch : dimensions.button,
          paddingVertical: spacing.sm,
          paddingHorizontal: variant === 'text' ? spacing.sm : spacing.ml,
          borderRadius: variant === 'text' ? radius.small : radius.medium,
          borderWidth: borders.hairline,
          borderColor: focused
            ? colors.primary
            : blocked
              ? colors.border
              : variant === 'danger'
                ? colors.errorSoft
                : variant === 'outlined'
                  ? colors.outline
                  : 'transparent',
          outlineWidth: focused ? borders.focus : 0,
          outlineColor: colors.primary,
          outlineOffset: borders.focus,
          backgroundColor:
            variant === 'primary'
              ? blocked
                ? colors.highest
                : colors.primary
              : variant === 'danger'
                ? colors.errorSoft
                : variant === 'outlined'
                  ? colors.surface
                  : 'transparent',
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          gap: spacing.s,
        },
      ]}
    >
      {loading ? (
        <ActivityIndicator
          size="small"
          color={text}
          accessibilityLabel="İşlem devam ediyor"
        />
      ) : icon ? (
        <Icon name={icon} size={iconSize.medium} color={text} />
      ) : null}
      <AppText
        variant="labelLarge"
        style={{
          color: text,
          textAlign: 'center',
          flexShrink: 1,
          // The bundled Medium face carries its weight. Extra Android synthesis
          // clipped trailing words in intrinsically measured button labels.
          fontWeight: 'normal',
          ...(variant === 'text'
            ? { fontSize: 14, lineHeight: 20, letterSpacing: 0.1 }
            : {}),
        }}
      >
        {label}
      </AppText>
    </TouchSurface>
  );
}

export function Field({
  label,
  icon,
  error,
  password = false,
  style,
  ...props
}: TextInputProps & {
  label: string;
  icon: IconName;
  error?: string;
  password?: boolean;
  ref?: Ref<TextInputInstance>;
}) {
  const { colors } = useTheme();
  const [focused, setFocused] = useState(false);
  const [hidden, setHidden] = useState(true);
  return (
    <View style={{ gap: spacing.s }}>
      <AppText
        variant="bodySmall"
        style={{
          color: error
            ? colors.error
            : focused
              ? colors.primary
              : colors.secondaryText,
        }}
      >
        {label}
      </AppText>
      <View
        style={{
          minHeight: dimensions.input,
          backgroundColor: colors.input,
          borderRadius: radius.medium,
          borderWidth: borders.hairline,
          borderColor: error
            ? colors.error
            : focused
              ? colors.primary
              : colors.border,
          flexDirection: 'row',
          alignItems: 'center',
          paddingLeft: spacing.sm,
          opacity: props.editable === false ? 0.6 : 1,
        }}
      >
        <Icon name={icon} size={iconSize.medium} color={colors.inputIcon} />
        <View style={{ flex: 1, minWidth: 0, marginLeft: spacing.sm }}>
          <TextInput
            {...props}
            accessibilityLabel={label}
            accessibilityHint={error}
            autoCapitalize={props.autoCapitalize ?? 'none'}
            autoCorrect={props.autoCorrect ?? false}
            placeholder={props.placeholder}
            placeholderTextColor={colors.muted}
            secureTextEntry={password && hidden}
            selectionColor={colors.primary}
            onFocus={(event) => {
              setFocused(true);
              props.onFocus?.(event);
            }}
            onBlur={(event) => {
              setFocused(false);
              props.onBlur?.(event);
            }}
            style={[
              typography.bodyLarge,
              {
                color: colors.text,
                paddingVertical: spacing.sm,
                paddingRight: spacing.m,
                minHeight: props.multiline ? 104 : dimensions.touch,
                textAlignVertical: props.multiline ? 'top' : 'center',
                includeFontPadding: false,
              },
              style,
            ]}
          />
        </View>
        {password && (
          <TouchSurface
            disabled={props.editable === false}
            accessibilityRole="button"
            accessibilityLabel={hidden ? 'Şifreyi göster' : 'Şifreyi gizle'}
            onPress={() => setHidden(!hidden)}
            style={{
              minWidth: dimensions.touch,
              minHeight: dimensions.touch,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon
              name={hidden ? 'visible' : 'hidden'}
              color={colors.inputIcon}
            />
          </TouchSurface>
        )}
      </View>
      {error && (
        <AppText
          accessibilityRole="alert"
          style={{
            color: colors.error,
            paddingHorizontal: spacing.xs,
          }}
        >
          {error}
        </AppText>
      )}
    </View>
  );
}

export function Card({
  children,
  style,
}: {
  children: ReactNode;
  style?: ViewStyle;
}) {
  const { colors } = useTheme();
  const reduce = useReducedMotion();
  return (
    <Animated.View
      style={[
        {
          backgroundColor: colors.surface,
          transitionProperty: ['backgroundColor', 'borderColor'],
          transitionDuration: reduce ? 0 : motion.theme,
          borderColor: colors.border,
          borderWidth: borders.hairline,
          borderRadius: radius.medium,
          padding: spacing.card,
        },
        style,
      ]}
    >
      {children}
    </Animated.View>
  );
}

export function AuthShell({
  children,
  maxWidth = dimensions.auth,
}: {
  children: ReactNode;
  maxWidth?: number;
}) {
  const { colors, mode } = useTheme();
  const { width, height } = useWindowDimensions();
  const logoSize = height < 600 ? 72 : 112;
  const insets = useSafeAreaInsets();
  return (
    <SafeAreaView style={styles.flex}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={Platform.OS === 'ios' ? insets.top : 0}
      >
        <ScrollView
          contentContainerStyle={styles.authScroll}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="on-drag"
        >
          <Animated.View
            entering={FadeIn.duration(motion.slow)
              .easing(Easing.out(Easing.cubic))
              .reduceMotion(ReduceMotion.System)}
            style={{ width: '100%', maxWidth }}
          >
            <View style={{ alignItems: 'center', marginBottom: spacing.l }}>
              <View
                style={{
                  width: logoSize,
                  height: logoSize,
                  padding: spacing.s,
                  borderRadius: radius.large,
                  borderWidth: 1,
                  borderColor: colors.border,
                  backgroundColor: colors.low,
                  boxShadow: shadow(mode, 'soft'),
                }}
              >
                <Image
                  source={require('../../assets/images/ekspersiz_logo.png')}
                  style={{ width: '100%', height: '100%' }}
                  resizeMode="contain"
                  resizeMethod="resize"
                  accessible={false}
                />
              </View>
              <Gap size={16} />
              <AppText
                variant="headlineSmall"
                style={{
                  fontFamily: fonts.black,
                  fontWeight: '900',
                  letterSpacing: -0.7,
                }}
              >
                EksperSiz
              </AppText>
              <Gap size={6} />
              <AppText
                style={{ textAlign: 'center', color: colors.secondaryText }}
              >
                AI destekli araç hasar analizi
              </AppText>
            </View>
            <Card
              style={{
                borderRadius: radius.xlarge,
                padding: width < 360 ? spacing.card : spacing.l,
              }}
            >
              {children}
            </Card>
          </Animated.View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

export function FormHeading({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <>
      <Gap size={10} />
      <AppText
        variant="headlineSmall"
        accessibilityRole="header"
        style={{ fontFamily: fonts.black, fontWeight: '900' }}
      >
        {title}
      </AppText>
      <Gap size={8} />
      <AppText>{description}</AppText>
      <Gap size={26} />
    </>
  );
}
const styles = StyleSheet.create({
  flex: { flex: 1 },
  authScroll: {
    flexGrow: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: spacing.page,
    paddingVertical: 26,
  },
});
