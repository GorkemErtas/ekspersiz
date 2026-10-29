import { useState, type ReactNode, type Ref } from 'react';
import {
  ActivityIndicator,
  Image,
  KeyboardAvoidingView,
  Platform,
  Pressable,
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
import {
  dimensions,
  fonts,
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
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => ({
        width: 48,
        height: 48,
        borderRadius: 16,
        backgroundColor: filled
          ? colors.primary
          : surface
            ? colors.surface
            : 'transparent',
        borderWidth: surface ? 1 : 0,
        borderColor: colors.border,
        alignItems: 'center',
        justifyContent: 'center',
        opacity: disabled ? 0.5 : pressed ? 0.75 : 1,
      })}
    >
      <Icon
        name={icon}
        color={color ?? (filled ? colors.onPrimary : colors.text)}
      />
    </Pressable>
  );
}
export function Icon({
  name,
  size = 22,
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
  variant?: 'primary' | 'outlined' | 'text';
}) {
  const { colors, mode } = useTheme();
  const [focused, setFocused] = useState(false);
  const blocked = disabled || loading;
  const text = blocked
    ? colors.secondaryText
    : variant === 'primary'
      ? colors.onPrimary
      : variant === 'text'
        ? mode === 'dark'
          ? colors.secondary
          : colors.primary
        : colors.text;
  return (
    <Pressable
      onPress={onPress}
      disabled={blocked}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: blocked, busy: loading }}
      accessibilityLiveRegion={loading ? 'polite' : 'none'}
      android_ripple={{ color: mode === 'dark' ? '#FFFFFF1F' : '#00000014' }}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      style={({ pressed }) => [
        {
          minHeight: variant === 'text' ? dimensions.touch : dimensions.button,
          paddingVertical:
            variant === 'text' ? 10 : variant === 'outlined' ? 12.8 : 14,
          paddingHorizontal: variant === 'text' ? 12 : 18,
          borderRadius: variant === 'text' ? radius.small : radius.medium,
          borderWidth: variant === 'outlined' ? (focused ? 2 : 1.2) : 0,
          borderColor: focused
            ? colors.primary
            : blocked
              ? colors.border
              : colors.outline,
          backgroundColor:
            variant === 'primary'
              ? blocked
                ? colors.highest
                : colors.primary
              : variant === 'outlined'
                ? colors.surface
                : 'transparent',
          opacity: pressed ? 0.88 : 1,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 10,
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
        <Icon name={icon} size={20} color={text} />
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
    </Pressable>
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
  const { fontScale } = useWindowDimensions();
  const [focused, setFocused] = useState(false);
  const [hidden, setHidden] = useState(true);
  const floating = focused || !!props.value;
  const borderWidth = focused ? 1.6 : 1;
  return (
    <View>
      <View
        style={{
          minHeight: 56,
          backgroundColor: colors.input,
          borderRadius: radius.medium,
          borderWidth,
          borderColor: error
            ? colors.error
            : focused
              ? colors.primary
              : colors.border,
          flexDirection: 'row',
          alignItems: 'center',
          paddingLeft: 12,
        }}
      >
        <Icon name={icon} size={24} color={colors.inputIcon} />
        <View style={{ flex: 1, marginLeft: 15 }}>
          {floating && (
            <AppText
              style={{
                position: 'absolute',
                top: -9 * fontScale,
                left: -4,
                backgroundColor: colors.input,
                paddingHorizontal: 4,
                fontSize: 12,
                lineHeight: 16,
                color: error
                  ? colors.error
                  : focused
                    ? colors.primary
                    : colors.secondaryText,
                fontFamily: fonts.semibold,
                fontWeight: '600',
              }}
            >
              {label}
            </AppText>
          )}
          {!floating && (
            <AppText
              pointerEvents="none"
              style={{
                position: 'absolute',
                top: 16 - borderWidth,
                fontSize: 16,
                lineHeight: 24,
                color: colors.secondaryText,
                fontFamily: fonts.semibold,
                fontWeight: '600',
              }}
            >
              {label}
            </AppText>
          )}
          <TextInput
            {...props}
            accessibilityLabel={label}
            accessibilityHint={error}
            autoCapitalize={props.autoCapitalize ?? 'none'}
            autoCorrect={props.autoCorrect ?? false}
            placeholder={floating ? props.placeholder : undefined}
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
                paddingVertical: 16 - borderWidth,
                paddingRight: 16,
                minHeight: 56 - borderWidth * 2,
                includeFontPadding: false,
              },
              style,
            ]}
          />
        </View>
        {password && (
          <Pressable
            disabled={props.editable === false}
            accessibilityRole="button"
            accessibilityLabel={hidden ? 'Şifreyi göster' : 'Şifreyi gizle'}
            onPress={() => setHidden(!hidden)}
            style={{
              minWidth: 48,
              minHeight: 48,
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon
              name={hidden ? 'visible' : 'hidden'}
              color={colors.inputIcon}
            />
          </Pressable>
        )}
      </View>
      {error && (
        <AppText
          accessibilityRole="alert"
          style={{
            fontSize: 12,
            color: colors.error,
            paddingHorizontal: 16,
            paddingTop: 6,
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
          borderWidth: 1,
          borderRadius: radius.large,
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
  const { width } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  return (
    <SafeAreaView style={styles.flex}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={insets.top}
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
            <View style={{ alignItems: 'center', marginBottom: 26 }}>
              <View
                style={{
                  width: 88,
                  height: 88,
                  borderRadius: 28,
                  boxShadow: shadow(mode, 'primary'),
                }}
              >
                <Image
                  source={require('../../assets/images/ekspersiz_logo.png')}
                  style={{ width: 88, height: 88, borderRadius: 28 }}
                  resizeMode="cover"
                  resizeMethod="resize"
                  resizeMultiplier={256 / 88}
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
                padding: width < 360 ? 17 : 22,
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
